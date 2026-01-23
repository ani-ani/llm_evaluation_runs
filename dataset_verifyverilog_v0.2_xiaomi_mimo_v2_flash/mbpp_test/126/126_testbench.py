import cocotb
from cocotb.triggers import Timer
import random

def python_sum(a, b):
    """Python reference implementation"""
    total = 0
    for i in range(1, min(a, b) + 1):
        if a % i == 0 and b % i == 0:
            total += i
    return total

@cocotb.test()
async def test_common_divisors_sum(dut):
    """Test common_divisors_sum module"""
    
    # Test case 1: a=10, b=15, expected sum=6 (divisors: 1, 5)
    dut.a.value = 10
    dut.b.value = 15
    await Timer(10, units='ns')
    result = int(dut.sum.value)
    expected = python_sum(10, 15)
    print(f"Test 1: a=10, b=15 => Result={result}, Expected={expected}")
    assert result == expected, f"Test 1 failed: got {result}, expected {expected}"
    
    # Test case 2: a=100, b=150, expected sum=93 (divisors: 1, 2, 5, 10, 25, 50)
    dut.a.value = 100
    dut.b.value = 150
    await Timer(10, units='ns')
    result = int(dut.sum.value)
    expected = python_sum(100, 150)
    print(f"Test 2: a=100, b=150 => Result={result}, Expected={expected}")
    assert result == expected, f"Test 2 failed: got {result}, expected {expected}"
    
    # Test case 3: a=4, b=6, expected sum=3 (divisors: 1, 2)
    dut.a.value = 4
    dut.b.value = 6
    await Timer(10, units='ns')
    result = int(dut.sum.value)
    expected = python_sum(4, 6)
    print(f"Test 3: a=4, b=6 => Result={result}, Expected={expected}")
    assert result == expected, f"Test 3 failed: got {result}, expected {expected}"
    
    # Test case 4: Edge case - same numbers
    dut.a.value = 12
    dut.b.value = 12
    await Timer(10, units='ns')
    result = int(dut.sum.value)
    expected = python_sum(12, 12)
    print(f"Test 4: a=12, b=12 => Result={result}, Expected={expected}")
    assert result == expected, f"Test 4 failed: got {result}, expected {expected}"
    
    # Test case 5: Coprime numbers (only common divisor is 1)
    dut.a.value = 7
    dut.b.value = 11
    await Timer(10, units='ns')
    result = int(dut.sum.value)
    expected = python_sum(7, 11)
    print(f"Test 5: a=7, b=11 => Result={result}, Expected={expected}")
    assert result == expected, f"Test 5 failed: got {result}, expected {expected}"
    
    print(f"
All tests passed!")