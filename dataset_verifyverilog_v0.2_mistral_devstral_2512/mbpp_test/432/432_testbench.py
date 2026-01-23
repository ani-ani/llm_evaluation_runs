import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def to_q16_16(value):
    """Convert decimal value to Q16.16 fixed-point representation"""
    return int(value * 65536)

def from_q16_16(value):
    """Convert Q16.16 fixed-point to decimal"""
    return value / 65536.0

@cocotb.test()
async def test_trapezium_median_basic(dut):
    """Test basic median calculation"""
    # Test case 1: base1=15, base2=25, expected=20
    dut.base1.value = to_q16_16(15.0)
    dut.base2.value = to_q16_16(25.0)
    await Timer(10, units='ns')
    
    expected = to_q16_16(20.0)
    actual = int(dut.median.value)
    
    if actual != expected:
        raise TestFailure(f"Test 1 failed: expected {expected} (20.0), got {actual} ({from_q16_16(actual):.2f})")
    print(f"Test 1 passed: base1=15, base2=25, median={from_q16_16(actual):.2f}")

@cocotb.test()
async def test_trapezium_median_case2(dut):
    """Test second test case"""
    # Test case 2: base1=10, base2=20, expected=15
    dut.base1.value = to_q16_16(10.0)
    dut.base2.value = to_q16_16(20.0)
    await Timer(10, units='ns')
    
    expected = to_q16_16(15.0)
    actual = int(dut.median.value)
    
    if actual != expected:
        raise TestFailure(f"Test 2 failed: expected {expected} (15.0), got {actual} ({from_q16_16(actual):.2f})")
    print(f"Test 2 passed: base1=10, base2=20, median={from_q16_16(actual):.2f}")

@cocotb.test()
async def test_trapezium_median_case3(dut):
    """Test third test case with fractional result"""
    # Test case 3: base1=6, base2=9, expected=7.5
    dut.base1.value = to_q16_16(6.0)
    dut.base2.value = to_q16_16(9.0)
    await Timer(10, units='ns')
    
    expected = to_q16_16(7.5)
    actual = int(dut.median.value)
    
    if actual != expected:
        raise TestFailure(f"Test 3 failed: expected {expected} (7.5), got {actual} ({from_q16_16(actual):.2f})")
    print(f"Test 3 passed: base1=6, base2=9, median={from_q16_16(actual):.2f}")

@cocotb.test()
async def test_trapezium_median_edge_cases(dut):
    """Test edge cases"""
    # Edge case 1: zeros
    dut.base1.value = 0
    dut.base2.value = 0
    await Timer(10, units='ns')
    assert int(dut.median.value) == 0, "Zero test failed"
    print("Edge case 1 passed: both bases 0")
    
    # Edge case 2: equal large values
    dut.base1.value = to_q16_16(1000.0)
    dut.base2.value = to_q16_16(1000.0)
    await Timer(10, units='ns')
    expected = to_q16_16(1000.0)
    assert int(dut.median.value) == expected, "Equal large values test failed"
    print("Edge case 2 passed: both bases 1000")
    
    # Edge case 3: one zero, one non-zero
    dut.base1.value = 0
    dut.base2.value = to_q16_16(100.0)
    await Timer(10, units='ns')
    expected = to_q16_16(50.0)
    assert int(dut.median.value) == expected, "Mixed zero test failed"
    print("Edge case 3 passed: base1=0, base2=100")

@cocotb.test()
async def test_trapezium_median_fractional_input(dut):
    """Test with fractional input values"""
    # Test with 3.5 and 5.5, expected = (3.5+5.5)/2 = 4.5
    dut.base1.value = to_q16_16(3.5)
    dut.base2.value = to_q16_16(5.5)
    await Timer(10, units='ns')
    
    expected = to_q16_16(4.5)
    actual = int(dut.median.value)
    
    if actual != expected:
        raise TestFailure(f"Fractional test failed: expected {expected} (4.5), got {actual} ({from_q16_16(actual):.2f})")
    print(f"Fractional test passed: base1=3.5, base2=5.5, median={from_q16_16(actual):.2f}")

@cocotb.test()
async def test_trapezium_median_summary(dut):
    """Summary of all tests"""
    test_count = 5
    passed_count = 0
    
    test_cases = [
        (15.0, 25.0, 20.0),
        (10.0, 20.0, 15.0),
        (6.0, 9.0, 7.5),
        (0.0, 0.0, 0.0),
        (123.45, 678.90, 401.175)
    ]
    
    for b1, b2, expected in test_cases:
        dut.base1.value = to_q16_16(b1)
        dut.base2.value = to_q16_16(b2)
        await Timer(10, units='ns')
        
        actual = from_q16_16(int(dut.median.value))
        if abs(actual - expected) < 0.0001:
            passed_count += 1
    
    print(f"
=== SUMMARY: {passed_count}/{test_count} tests passed ===")
    assert passed_count == test_count, f"Only {passed_count} out of {test_count} tests passed"
