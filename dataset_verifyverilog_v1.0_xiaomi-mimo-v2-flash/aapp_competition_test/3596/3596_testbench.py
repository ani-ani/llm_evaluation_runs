import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    # Handle signed
    if v >= (1 << (32-1)):
        return (v - (1 << 32)) / (1 << frac)
    return v / (1 << frac)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def encode_params(r, s, n, k, l):
    # Pack into 64-bit value
    val = 0
    val |= (r & 0x3FF)          # bits 9:0
    val |= ((s & 0x3FF) << 10)  # bits 19:10
    val |= ((n & 0x3FF) << 20)  # bits 29:20
    val |= ((k & 0x3FF) << 30)  # bits 39:30
    val |= ((l & 0x3FF) << 40)  # bits 49:40
    return val

def compute_expected(r, s, n, k, l):
    """Compute expected result using Python reference"""
    # Constants
    pi = 3.141592653589793
    e = 2.718281828459045
    
    # As derived: g(n) = 0 (since g is (deg+1)th derivative of polynomial)
    # deg(P_s) = r + s
    # g = d^(r+s+1)/dx^(r+s+1) P_s(x) = 0
    
    l_float = float(l)
    term1 = (l_float * l_float) / (pi * e)
    term2 = 1.0 / (l_float + 1.0)
    
    return term1 + term2

async def run_test_case(dut, r, s, n, k, l, expected):
    """Run a single test case"""
    # Configure parameters
    params = encode_params(r, s, n, k, l)
    
    # Write params to dut
    if has_signal(dut, 'params'):
        dut.params.value = clamp_to_width(params, 64)
    else:
        # If individual signals exist, set them
        for i in range(10):
            bit = (params >> i) & 1
            # This is simplified - ideally individual signals would exist
            pass
    
    # Start computation
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, max_cycles=256)
    else:
        # Combinational logic
        await Timer(100, units='ns')
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined")
    
    result_raw = int(dut.result.value)
    result_float = fixed_to_float(result_raw, frac=16)
    
    # Allow tolerance for fixed-point approximation
    tolerance = 0.01
    diff = abs(result_float - expected)
    
    if diff > tolerance:
        raise TestFailure(f"Expected {expected:.6f}, got {result_float:.6f} (diff={diff:.6f})")
    
    return result_float

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_arnar_location(dut):
    """Test the Arnar's opponent location calculator"""
    
    # Setup clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut, cycles=2)
    
    # Test cases
    test_cases = [
        # (r, s, n, k, l, expected_result)
        (9, 99, 9, 99, 9, 9.585073),
        (17, 3, 17, 2, 9, 9.585073),
        (5, 5, 5, 5, 5, 9.585073),
        (1, 1, 1, 1, 1, 9.585073),
    ]
    
    passed = 0
    failed = 0
    
    for i, (r, s, n, k, l, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: r={r}, s={s}, n={n}, k={k}, l={l}")
        try:
            result = await run_test_case(dut, r, s, n, k, l, expected)
            cocotb.log.info(f"  Result: {result:.6f} (expected: {expected:.6f})")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_basic_calculation(dut):
    """Test basic calculation with known parameters"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut, cycles=2)
    
    # Simple test: l=9, compute expected
    # (81 * 1/(pi*e)) + 1/10
    pi_e = 3.141592653589793 * 2.718281828459045
    inv_pi_e = 1.0 / pi_e
    term1 = 81 * inv_pi_e
    term2 = 0.1
    expected = term1 + term2
    
    # Encode params
    r, s, n, k, l = 9, 99, 9, 99, 9
    params = encode_params(r, s, n, k, l)
    
    if has_signal(dut, 'params'):
        dut.params.value = clamp_to_width(params, 64)
    
    if is_seq and has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut, max_cycles=256)
    else:
        await Timer(100, units='ns')
    
    result_raw = int(dut.result.value)
    result_float = fixed_to_float(result_raw, frac=16)
    
    # Allow small tolerance
    tolerance = 0.02  # Slightly higher for basic test
    if abs(result_float - expected) > tolerance:
        raise TestFailure(f"Basic test failed: expected {expected:.6f}, got {result_float:.6f}")
    
    cocotb.log.info(f"Basic test passed: {result_float:.6f} ≈ {expected:.6f}")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases with small parameters"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut, cycles=2)
    
    # Minimum values
    test_cases = [
        (1, 1, 1, 1, 1),
        (10, 10, 10, 10, 10),
        (25, 5, 100, 50, 50),
    ]
    
    for (r, s, n, k, l) in test_cases:
        # Compute expected
        pi_e = 3.141592653589793 * 2.718281828459045
        inv_pi_e = 1.0 / pi_e
        term1 = (l * l) * inv_pi_e
        term2 = 1.0 / (l + 1)
        expected = term1 + term2
        
        params = encode_params(r, s, n, k, l)
        
        if has_signal(dut, 'params'):
            dut.params.value = clamp_to_width(params, 64)
        
        if is_seq and has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut, max_cycles=256)
        else:
            await Timer(100, units='ns')
        
        result_raw = int(dut.result.value)
        result_float = fixed_to_float(result_raw, frac=16)
        
        tolerance = 0.02
        if abs(result_float - expected) > tolerance:
            raise TestFailure(f"Edge case r={r}, s={s}, l={l}: expected {expected:.6f}, got {result_float:.6f}")
        
        cocotb.log.info(f"Edge case passed: r={r}, s={s}, l={l} -> {result_float:.6f}")

@cocotb.test(timeout_time=3000, timeout_unit="ms")
async def test_comprehensive(dut):
    """Comprehensive test with multiple iterations"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut, cycles=2)
    
    passed = 0
    failed = 0
    
    # Various combinations
    test_cases = [
        (5, 5, 10, 5, 5),
        (15, 3, 20, 10, 7),
        (20, 4, 30, 15, 12),
        (25, 5, 40, 20, 15),
    ]
    
    for (r, s, n, k, l) in test_cases:
        pi_e = 3.141592653589793 * 2.718281828459045
        inv_pi_e = 1.0 / pi_e
        term1 = (l * l) * inv_pi_e
        term2 = 1.0 / (l + 1)
        expected = term1 + term2
        
        params = encode_params(r, s, n, k, l)
        
        if has_signal(dut, 'params'):
            dut.params.value = clamp_to_width(params, 64)
        
        if is_seq and has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut, max_cycles=256)
        else:
            await Timer(100, units='ns')
        
        result_raw = int(dut.result.value)
        result_float = fixed_to_float(result_raw, frac=16)
        
        tolerance = 0.03
        diff = abs(result_float - expected)
        
        if diff > tolerance:
            cocotb.log.error(f"FAIL: r={r}, s={s}, l={l}: expected {expected:.6f}, got {result_float:.6f}, diff={diff:.6f}")
            failed += 1
        else:
            cocotb.log.info(f"PASS: r={r}, s={s}, l={l} -> {result_float:.6f} (diff={diff:.4f})")
            passed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"Comprehensive test: {passed} passed, {failed} failed")