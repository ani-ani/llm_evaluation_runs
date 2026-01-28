import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 256

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def fixed_to_float(val, frac=16):
    return val / (1 << frac)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, vals, width):
    # Write to individual array elements (common in Verilog testbenches for arrays)
    for i in range(ARRAY_SIZE):
        if i < len(vals):
            dut.arr[i].value = clamp_to_width(vals[i], width)
        else:
            dut.arr[i].value = 0  # Default for unused elements

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_zero_ratio(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        ([0, 1, 2, -1, -5, 6, 0, -3, -2, 3, 4, 6, 8], 0.181818, "mixed zeros"),
        ([2, 1, 2, -1, -5, 6, 4, -3, -2, 3, 4, 6, 8], 0.0, "no zeros"),
        ([2, 4, -6, -9, 11, -12, 14, -5, 17], 0.0, "no zeros short")
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Truncate input to array size (max 8 elements for this HW design)
            # Note: The original Python example had 13 elements, but we scale to 8
            # We'll use the first 8 elements for the test to fit HW constraints
            inp_trunc = inp[:8]
            actual_len = len(inp_trunc)
            
            # Calculate expected ratio based on truncated input
            n = actual_len
            n1 = sum(1 for x in inp_trunc if x == 0)
            exp_actual = n1 / (n - n1) if (n - n1) != 0 else 0.0
            
            # Write inputs
            await write_array(dut, inp_trunc, DATA_WIDTH)
            dut.len.value = actual_len
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result_val = safe_int(dut.result.value)
            result_float = fixed_to_float(result_val)
            
            # Compare with tolerance (relative tolerance 0.001)
            if not math.isclose(result_float, exp_actual, rel_tol=0.001):
                raise TestFailure(f"Expected {exp_actual:.6f}, got {result_float:.6f} (raw: {result_val})")
            
            passed += 1
            cocotb.log.info(f"  PASS: Result = {result_float:.6f} (raw {result_val})")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")