import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
ARRAY_SIZE = 16
LEN_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    # For unsigned
    return min((1 << bits) - 1, max(0, v))

def clamp_signed(v, bits):
    # For signed values in 8-bit range
    max_val = (1 << (bits - 1)) - 1
    min_val = -(1 << (bits - 1))
    return max(min_val, min(max_val, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Helper to calculate expected result
def calculate_expected(arr):
    largest_index = -1
    for i in range(1, len(arr)):
        if arr[i] < arr[i-1]:
            largest_index = i
    return largest_index

async def write_array(dut, vals):
    # Write each element individually to avoid assignment errors
    for i in range(ARRAY_SIZE):
        if i < len(vals):
            # Clamp signed value to 8-bit range
            val = clamp_signed(vals[i], DATA_WIDTH)
            # Convert to unsigned representation for assignment (signed logic in HDL will handle)
            if val < 0:
                val = (1 << DATA_WIDTH) + val
            getattr(dut, f'arr_{i}').value = val
        else:
            getattr(dut, f'arr_{i}').value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_can_arrange(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic assumed
        pass
    
    test_cases = [
        ([1, 2, 4, 3, 5], 3, "Decrease at index 3"),
        ([1, 2, 4, 5], -1, "Strictly increasing"),
        ([1, 4, 2, 5, 6, 7, 8, 9, 10], 2, "Decrease at index 2"),
        ([4, 8, 5, 7, 3], 4, "Decrease at index 1 and 4, largest is 4"),
        ([], -1, "Empty array"),
        ([5], -1, "Single element"),
        ([1, 3, 2], 2, "Decrease at index 2"),
        ([-5, 2, 1], 2, "Signed values, decrease at 2"),
        ([10, 9, 8, 7, 6, 5, 4, 3, 2, 1], 9, "Strictly decreasing"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: {inp}")
        try:
            # Write inputs
            if has_signal(dut, 'clk'):
                await reset_dut(dut, cycles=1) # Quick reset between tests
                await write_array(dut, inp)
                dut.len.value = len(inp)
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                    
                raw_res = int(dut.result.value)
                # Convert 4-bit signed (0-15 or -1=1111) to Python int
                if raw_res >= 8: # 4-bit signed: 8 is -8, 15 is -1
                    result = raw_res - 16
                else:
                    result = raw_res
                
            else:
                # Combinational mode
                await write_array(dut, inp)
                dut.len.value = len(inp)
                await Timer(50, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                raw_res = int(dut.result.value)
                if raw_res >= 8:
                    result = raw_res - 16
                else:
                    result = raw_res

            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
