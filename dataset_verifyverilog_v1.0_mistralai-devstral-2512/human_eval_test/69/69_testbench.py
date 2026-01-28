import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 16
LEN_WIDTH = 4
RESULT_WIDTH = 9
CLK_NS = 10
MAX_CYCLES = 1500

# Helpers from Section A
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, vals):
    # Pad or truncate to ARRAY_SIZE
    padded_vals = list(vals) + [0] * (ARRAY_SIZE - len(vals))
    for i, v in enumerate(padded_vals):
        dut.arr[i].value = clamp_to_width(v, DATA_WIDTH)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_max_frequency_match(dut):
    # Clock setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Define test cases (list, expected_result)
    test_cases = [
        ([4, 1, 2, 2, 3, 1], 2),
        ([1, 2, 2, 3, 3, 3, 4, 4, 4], 3),
        ([5, 5, 4, 4, 4], -1),
        ([5, 5, 5, 5, 1], 1),
        ([4, 1, 4, 1, 4, 4], 4),
        ([3, 3], -1),
        ([8, 8, 8, 8, 8, 8, 8, 8], 8),
        ([2, 3, 3, 2, 2], 2),
        ([10], -1),
        ([1], 1)
    ]

    passed = 0
    failed = 0

    for i, (inp_list, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: Input={inp_list}, Expected={expected}")
        
        try:
            # Write input array
            await write_array(dut, inp_list)
            
            # Set length
            dut.len.value = len(inp_list)
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            # Convert 9-bit 2's complement if negative
            if result >= (1 << (RESULT_WIDTH - 1)):
                result -= (1 << RESULT_WIDTH)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} Failed: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)

    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")
