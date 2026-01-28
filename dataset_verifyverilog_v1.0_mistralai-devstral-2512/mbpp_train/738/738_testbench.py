import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Include required helpers
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

# Fixed-point conversion
Q8_8_SCALE = 256
FLOAT_TO_FIXED = lambda f: int(f * Q8_8_SCALE)

def float_to_fixed(f):
    return int(f * Q8_8_SCALE)

def fixed_to_float(fixed):
    return fixed / Q8_8_SCALE

# Constants
DATA_WIDTH = 16
N_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 20

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_geometric_sum(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (n_input, expected_sum_float, description)
    test_cases = [
        (0, 0.0, "n=0: empty sum"),
        (4, 1.9375, "n=4: 1 + 1/2 + 1/4 + 1/8"),
        (7, 1.9921875, "n=7: first 7 terms"),
        (8, 1.99609375, "n=8: first 8 terms"),
        (15, 1.9999, "n=15: max value"),
    ]
    
    passed = failed = 0
    
    for i, (n_input, expected_float, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {desc}")
        cocotb.log.info(f"  Input n = {n_input}, expected sum = {expected_float}")
        
        try:
            # Set inputs
            dut.n.value = n_input
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.sum.value):
                raise TestFailure("Result signal undefined")
            
            result_raw = int(dut.sum.value)
            result_float = fixed_to_float(result_raw)
            
            # Calculate expected fixed-point value
            expected_fixed = float_to_fixed(expected_float)
            
            cocotb.log.info(f"  Result: {result_raw} (0x{result_raw:X}), float = {result_float:.10f}")
            cocotb.log.info(f"  Expected: {expected_fixed} (0x{expected_fixed:X}), float = {expected_float}")
            
            # Allow small rounding error in fixed-point
            # In Q8.8, error can be up to ~0.004 (1 unit)
            error = abs(result_raw - expected_fixed)
            
            # For n=15, allow more tolerance due to accumulated error
            if n_input == 15:
                tolerance = 2
            else:
                tolerance = 1
            
            if error > tolerance:
                raise TestFailure(f"Error {error} exceeds tolerance {tolerance}")
            
            # Also verify done signal was 1
            if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
                raise TestFailure("Done signal not asserted")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")