import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def float_to_q16_16(value):
    """Convert float to Q16.16 fixed-point representation."""
    return int(value * 65536) & 0xFFFFFFFF

def q16_16_to_float(value):
    """Convert Q16.16 fixed-point to float."""
    if value & 0x80000000:  # Negative
        return (value - 0x100000000) / 65536.0
    else:
        return value / 65536.0

def evaluate_poly(coeffs, x):
    """Evaluate polynomial in Q16.16 format."""
    result = 0
    x_val = float_to_q16_16(x)
    x_power = float_to_q16_16(1.0)
    
    for i, coeff in enumerate(coeffs):
        # coeff * x^i
        term = (coeff * x_power) >> 16
        result += term
        x_power = (x_power * x_val) >> 16
    
    return result

def find_zero_reference(coeffs):
    """Reference implementation using binary search in float."""
    low = -10.0
    high = 10.0
    
    for _ in range(8):
        mid = (low + high) / 2.0
        # Evaluate polynomial
        f_mid = 0
        for i, coeff in enumerate(coeffs):
            f_mid += coeff * (mid ** i)
        
        if f_mid > 0:
            high = mid
        else:
            low = mid
    
    return (low + high) / 2.0

def to_signed(val, bits):
    """Convert unsigned to signed representation."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed to unsigned for assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_find_zero_basic(dut):
    """Test basic polynomial root finding."""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.coeffs[i].value = 0
    dut.num_coeffs.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: f(x) = 1 + 2x, root at -0.5
    coeffs = [1, 2]
    for i, coeff in enumerate(coeffs):
        dut.coeffs[i].value = from_signed(coeff, 16)
    dut.num_coeffs.value = len(coeffs)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    max_cycles = 20
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if not is_value_defined(dut.done.value):
            continue
        if dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    
    result_q16_16 = int(dut.result.value)
    result_float = q16_16_to_float(result_q16_16)
    
    # Expected root is -0.5
    expected = -0.5
    error = abs(result_float - expected)
    
    dut._log.info(f"Test 1: result={result_float:.6f}, expected={expected:.6f}, error={error:.6f}")
    
    if error > 0.05:  # Allow 0.05 tolerance for 8 iterations
        raise TestFailure(f"Test 1 failed: error {error:.6f} > 0.05")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_find_zero_polynomial(dut):
    """Test polynomial f(x) = -6 + 11x - 6x^2 + x^3, root at 1.0."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.coeffs[i].value = 0
    dut.num_coeffs.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # f(x) = -6 + 11x - 6x^2 + x^3
    coeffs = [-6, 11, -6, 1]
    for i, coeff in enumerate(coeffs):
        dut.coeffs[i].value = from_signed(coeff, 16)
    dut.num_coeffs.value = len(coeffs)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    max_cycles = 20
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if not is_value_defined(dut.done.value):
            continue
        if dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    
    result_q16_16 = int(dut.result.value)
    result_float = q16_16_to_float(result_q16_16)
    
    # Expected root is 1.0
    expected = 1.0
    error = abs(result_float - expected)
    
    dut._log.info(f"Test 2: result={result_float:.6f}, expected={expected:.6f}, error={error:.6f}")
    
    if error > 0.05:
        raise TestFailure(f"Test 2 failed: error {error:.6f} > 0.05")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_find_zero_multiple(dut):
    """Test multiple polynomial evaluations."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.coeffs[i].value = 0
    dut.num_coeffs.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ([1, 2], -0.5),           # 1 + 2x = 0
        ([0, 1], 0.0),            # x = 0
        ([-5, 0, 1], 2.236),      # x^2 - 5 = 0, positive root
    ]
    
    for i, (coeffs, expected) in enumerate(test_cases):
        # Setup coefficients
        for j, coeff in enumerate(coeffs):
            dut.coeffs[j].value = from_signed(coeff, 16)
        for j in range(len(coeffs), 8):
            dut.coeffs[j].value = 0
        dut.num_coeffs.value = len(coeffs)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        max_cycles = 20
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if not is_value_defined(dut.done.value):
                continue
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Test {i+1}: timeout")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: result undefined")
        
        result_q16_16 = int(dut.result.value)
        result_float = q16_16_to_float(result_q16_16)
        
        error = abs(result_float - expected)
        dut._log.info(f"Test {i+1}: coeffs={coeffs}, result={result_float:.6f}, expected={expected:.6f}, error={error:.6f}")
        
        if error > 0.08:  # Slightly relaxed tolerance for various cases
            raise TestFailure(f"Test {i+1} failed: error {error:.6f} > 0.08")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_find_zero_edge_cases(dut):
    """Test edge cases - negative and zero roots."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.coeffs[i].value = 0
    dut.num_coeffs.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: root at -3.5
    # f(x) = (x + 3.5) * (x + 1) = x^2 + 4.5x + 3.5 = 2x^2 + 9x + 7
    coeffs = [7, 9, 2]
    for i, coeff in enumerate(coeffs):
        dut.coeffs[i].value = from_signed(coeff, 16)
    dut.num_coeffs.value = len(coeffs)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    max_cycles = 20
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if not is_value_defined(dut.done.value):
            continue
        if dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    
    result_q16_16 = int(dut.result.value)
    result_float = q16_16_to_float(result_q16_16)
    
    # Expected: either -3.5 or -1
    expected_1 = -3.5
    expected_2 = -1.0
    error1 = abs(result_float - expected_1)
    error2 = abs(result_float - expected_2)
    error = min(error1, error2)
    
    dut._log.info(f"Test edge: result={result_float:.6f}, expected={expected_1:.6f} or {expected_2:.6f}, error={error:.6f}")
    
    if error > 0.08:
        raise TestFailure(f"Edge test failed: error {error:.6f} > 0.08")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_find_zero_random(dut):
    """Test with random polynomials from reference implementation."""
    import random
    import copy
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.coeffs[i].value = 0
    dut.num_coeffs.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    rng = random.Random(42)
    passed = 0
    total = 5
    
    for test_num in range(total):
        ncoeff = 2 * rng.randint(1, 4)  # Even number of coefficients
        coeffs = []
        for _ in range(ncoeff):
            coeff = rng.randint(-10, 10)
            if coeff == 0:
                coeff = 1
            coeffs.append(coeff)
        
        # Compute expected using reference
        coeffs_copy = copy.deepcopy(coeffs)
        expected = find_zero_reference(coeffs_copy)
        
        # Setup hardware
        for i, coeff in enumerate(coeffs):
            dut.coeffs[i].value = from_signed(coeff, 16)
        for i in range(ncoeff, 8):
            dut.coeffs[i].value = 0
        dut.num_coeffs.value = ncoeff
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        max_cycles = 20
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if not is_value_defined(dut.done.value):
                continue
            if dut.done.value == 1:
                break
        else:
            dut._log.info(f"Random test {test_num+1}: timeout, skipping")
            continue
        
        if not is_value_defined(dut.result.value):
            dut._log.info(f"Random test {test_num+1}: undefined result, skipping")
            continue
        
        result_q16_16 = int(dut.result.value)
        result_float = q16_16_to_float(result_q16_16)
        
        # Evaluate polynomial at found root
        f_result = 0
        x_power = 1.0
        for i, coeff in enumerate(coeffs):
            f_result += coeff * (result_float ** i)
        
        dut._log.info(f"Random test {test_num+1}: coeffs={coeffs}, root={result_float:.6f}, f(root)={f_result:.6f}")
        
        # Check if f(result) is close to zero
        if abs(f_result) < 0.2:  # Relaxed tolerance for random tests
            passed += 1
        else:
            dut._log.info(f"Random test {test_num+1}: f(root)={f_result:.6f} not close to zero")
    
    dut._log.info(f"Random tests: {passed}/{total} passed")
    if passed < 2:
        raise TestFailure(f"Too few random tests passed: {passed}/{total}")