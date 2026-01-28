import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
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
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array(dut, name, vals, width):
    # Clamp and write each element individually
    clamped_vals = [clamp_to_width(v, width) for v in vals]
    for i, v in enumerate(clamped_vals):
        dut.__getattr__(name)[i].value = v

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_pairs_sum_to_zero(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational, just wait
        await Timer(100, units='ns')
    
    # Test cases with expected results
    test_cases = [
        ([1, 3, 5, 0], 0, "No zero sum"),
        ([1, 3, -2, 1], 0, "No pair (duplicate -2,1 but -2+2=0 not present)"),
        ([1, 2, 3, 7], 0, "All positive"),
        ([2, 4, -5, 3, 5, 7], 1, "-5 + 5 = 0"),
        ([1], 0, "Single element"),
        ([-3, 9, -1, 3, 2, 30], 1, "-3 + 3 = 0"),
        ([-3, 9, -1, 3, 2, 31], 1, "-3 + 3 = 0"),
        ([-3, 9, -1, 4, 2, 30], 0, "No zero sum"),
        ([-3, 9, -1, 4, 2, 31], 0, "No zero sum"),
        ([0, 1, 2], 0, "0 alone (need pair)"),
        ([0, 0, 1], 1, "Two zeros"),
        ([-1, 1, -2, 2], 1, "Multiple pairs"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Prepare input
            arr_vals = inp[:ARRAY_SIZE]  # Truncate if too long
            arr_len = len(arr_vals)
            
            # Pad to array size with 0
            while len(arr_vals) < ARRAY_SIZE:
                arr_vals.append(0)
            
            # Write inputs
            await write_array(dut, 'arr', arr_vals, DATA_WIDTH)
            
            if has_signal(dut, 'len'):
                dut.len.value = arr_len
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            if is_seq:
                # Reset between tests
                await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed!")