import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import numpy as np

# Helper function to convert float to Q16.16
def float_to_q16_16(x):
    return int(x * 65536) & 0xFFFFFFFF

# Helper function to convert Q16.16 to float
def q16_16_to_float(x):
    if x & 0x80000000:  # Negative
        return -((~x + 1) / 65536.0)
    return x / 65536.0

# Helper to compute expected result for adapted problem
def compute_expected(n_val, numbers):
    # Count fractional numbers and sum fractions
    frac_count = 0
    frac_sum = 0
    for num in numbers:
        frac = num & 0xFFFF
        if frac != 0:
            frac_count += 1
            frac_sum += frac
    
    # Calculate bounds for k (number of round-ups)
    int_count = 2 * n_val - frac_count
    min_up = max(0, n_val - int_count)
    max_up = min(n_val, frac_count)
    
    # Target half-unit per fractional number is 0.5 = 0x00008000
    # We want to minimize |frac_sum - k * 0x00008000|
    best_error = 0xFFFFFFFF
    
    # Brute force search for small n
    for k in range(min_up, max_up + 1):
        error = abs(frac_sum - k * 0x8000)
        if error < best_error:
            best_error = error
    
    return best_error

@cocotb.test()
async def test_min_rounding_error(dut):
    """Test the min_rounding_error module"""
    
    # Create and start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        setattr(dut, f'numbers_{i}_i', 0)
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("Starting tests...")
    passed = 0
    total = 0
    
    # Test case 1: Original example 0.000 0.500 0.750 1.000 2.000 3.000
    total += 1
    n_val = 3
    numbers = [
        float_to_q16_16(0.000),
        float_to_q16_16(0.500),
        float_to_q16_16(0.750),
        float_to_q16_16(1.000),
        float_to_q16_16(2.000),
        float_to_q16_16(3.000),
        0,  # Padding to 8 elements
        0
    ]
    
    dut.n.value = n_val
    for i in range(8):
        getattr(dut, f'numbers_{i}_i').value = numbers[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result = dut.result.value
    expected = compute_expected(n_val, numbers)
    
    if abs(result - expected) <= 1:  # Allow small rounding errors
        print(f"Test 1 PASSED: result={result}, expected={expected}")
        passed += 1
    else:
        print(f"Test 1 FAILED: result={result}, expected={expected}")
    
    await RisingEdge(dut.clk)
    
    # Test case 2: Original example with decimals
    total += 1
    n_val = 3
    numbers = [
        float_to_q16_16(4469.000),
        float_to_q16_16(6526.000),
        float_to_q16_16(4864.000),
        float_to_q16_16(9356.383),
        float_to_q16_16(7490.000),
        float_to_q16_16(995.896),
        0, 0
    ]
    
    dut.n.value = n_val
    for i in range(8):
        getattr(dut, f'numbers_{i}_i').value = numbers[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result = dut.result.value
    expected = compute_expected(n_val, numbers)
    
    if abs(result - expected) <= 1:
        print(f"Test 2 PASSED: result={result}, expected={expected}")
        passed += 1
    else:
        print(f"Test 2 FAILED: result={result}, expected={expected}")
    
    await RisingEdge(dut.clk)
    
    # Test case 3: All integers (should be 0)
    total += 1
    n_val = 2
    numbers = [
        float_to_q16_16(1.000),
        float_to_q16_16(2.000),
        float_to_q16_16(3.000),
        float_to_q16_16(4.000),
        0, 0, 0, 0
    ]
    
    dut.n.value = n_val
    for i in range(8):
        getattr(dut, f'numbers_{i}_i').value = numbers[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result = dut.result.value
    expected = 0
    
    if result == 0:
        print(f"Test 3 PASSED: result={result}, expected={expected}")
        passed += 1
    else:
        print(f"Test 3 FAILED: result={result}, expected={expected}")
    
    await RisingEdge(dut.clk)
    
    # Test case 4: Small fractional parts (0.001)
    total += 1
    n_val = 2
    numbers = [
        float_to_q16_16(0.001),
        float_to_q16_16(0.001),
        float_to_q16_16(0.001),
        float_to_q16_16(0.001),
        0, 0, 0, 0
    ]
    
    dut.n.value = n_val
    for i in range(8):
        getattr(dut, f'numbers_{i}_i').value = numbers[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result = dut.result.value
    expected = compute_expected(n_val, numbers)
    
    if abs(result - expected) <= 1:
        print(f"Test 4 PASSED: result={result}, expected={expected}")
        passed += 1
    else:
        print(f"Test 4 FAILED: result={result}, expected={expected}")
    
    await RisingEdge(dut.clk)
    
    # Test case 5: Edge case - maximum n=4
    total += 1
    n_val = 4
    numbers = [
        float_to_q16_16(0.100),
        float_to_q16_16(0.200),
        float_to_q16_16(0.300),
        float_to_q16_16(0.400),
        float_to_q16_16(0.500),
        float_to_q16_16(0.600),
        float_to_q16_16(0.700),
        float_to_q16_16(0.800)
    ]
    
    dut.n.value = n_val
    for i in range(8):
        getattr(dut, f'numbers_{i}_i').value = numbers[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result = dut.result.value
    expected = compute_expected(n_val, numbers)
    
    if abs(result - expected) <= 1:
        print(f"Test 5 PASSED: result={result}, expected={expected}")
        passed += 1
    else:
        print(f"Test 5 FAILED: result={result}, expected={expected}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
