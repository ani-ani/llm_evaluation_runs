import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 200

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Fixed-point conversion
INT_BITS = 16
FRAC_BITS = 16
SCALE = 1 << FRAC_BITS

def int_to_fp(val):
    return val << FRAC_BITS

def fp_to_float(val):
    return val / SCALE

def calc_expected(a_int, b_int):
    if b_int > a_int:
        return None  # -1
    if a_int == b_int:
        return int_to_fp(a_int)
    
    min_x = float('inf')
    found = False
    
    # We check k values. The Python logic finds the *best* k by integer division.
    # However, we are simulating the hardware loop logic (1..64).
    # We will match the hardware by iterating k in Python too.
    
    # Note: The Python solution `(a+b)/2/k` uses the largest possible k such that denominator is valid.
    # In hardware, we are iterating k from 1 upwards and keeping the minimum result.
    # This is a valid approximation for bounded k.
    
    for k in range(1, 65):
        # Check case 1: (a - b) / (2*k)
        if a_int - b_int >= 2 * k * b_int:
            val = (a_int - b_int) / (2 * k)
            fp_val = int(val * SCALE)  # float to fp
            if fp_val < min_x:
                min_x = fp_val
                found = True
        
        # Check case 2: (a + b) / (2*k)
        if a_int + b_int >= 2 * k * b_int:
            val = (a_int + b_int) / (2 * k)
            fp_val = int(val * SCALE)
            if fp_val < min_x:
                min_x = fp_val
                found = True
            
    if not found:
        return None
    return int(min_x)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_polyline(dut):
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (a, b)
    test_cases = [
        (3, 1, 1.0),
        (1, 3, None),
        (4, 1, 1.25),
        (1000000000, 1000000000, 1000000000.0),
        (1000000000, 1, 1.000000001),
        (11, 5, 8.0),
        (30, 5, 5.833333333333),
        (5, 1, 1.0)
    ]
    
    passed = 0
    failed = 0
    
    for i, (a_in, b_in, expected_float) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: a={a_in}, b={b_in}, exp={expected_float}")
        
        # Set inputs (assuming 32-bit inputs for simplicity, usually 10^9 fits in 30 bits)
        dut.a_in.value = int_to_fp(a_in)
        dut.b_in.value = int_to_fp(b_in)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        done = False
        while timeout < 100:
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
            timeout += 1
            
        if not done:
            cocotb.log.error(f"Test {i+1}: Timeout waiting for done")
            failed += 1
            continue
            
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Test {i+1}: Result undefined")
            failed += 1
            continue
            
        res_raw = int(dut.result.value)
        
        # Calculate expected from hardware logic (bounded loop)
        expected_hw = calc_expected(a_in, b_in)
        
        if expected_float is None:
            # Expect -1
            if res_raw == 0xFFFFFFFF:
                cocotb.log.info(f"Test {i+1}: PASS (Correctly returned -1)")
                passed += 1
            else:
                cocotb.log.error(f"Test {i+1}: FAIL (Expected -1, got {fp_to_float(res_raw)})")
                failed += 1
        else:
            # Compare FP values
            res_float = fp_to_float(res_raw)
            exp_val = expected_float
            
            # The hardware might differ slightly from optimal due to bounded k
            # But for these tests, the bounded logic should hold or be close.
            # We allow small tolerance for fixed point error
            diff = abs(res_float - exp_val)
            rel_err = diff / exp_val if exp_val > 0 else diff
            
            if rel_err < 0.01 or diff < 0.001:
                cocotb.log.info(f"Test {i+1}: PASS (Got {res_float:.9f}, Expected ~{exp_val:.9f})")
                passed += 1
            else:
                cocotb.log.error(f"Test {i+1}: FAIL (Got {res_float:.9f}, Expected {exp_val:.9f})")
                failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
