import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

def calculate_expected(l, r):
    """Calculate expected sum of odd numbers in range [l,r]"""
    term_r = (r + 1) // 2
    term_l = l // 2
    sq_r = term_r * term_r
    sq_l = term_l * term_l
    return sq_r - sq_l

@cocotb.test()
async def test_sum_odd_range(dut):
    """Test sum of odd numbers in range"""
    
    # Initialize inputs
    dut.l.value = 0
    dut.r.value = 0
    
    await Timer(10, units='ns')
    
    # Test case 1: l=2, r=5, expected=8
    dut.l.value = 2
    dut.r.value = 5
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = calculate_expected(2, 5)
    print(f"Test 1: l=2, r=5 => result={result}, expected={expected}")
    if result != expected:
        raise TestFailure(f"Test 1 failed: got {result}, expected {expected}")
    
    # Test case 2: l=5, r=7, expected=12
    dut.l.value = 5
    dut.r.value = 7
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = calculate_expected(5, 7)
    print(f"Test 2: l=5, r=7 => result={result}, expected={expected}")
    if result != expected:
        raise TestFailure(f"Test 2 failed: got {result}, expected {expected}")
    
    # Test case 3: l=7, r=13, expected=40
    dut.l.value = 7
    dut.r.value = 13
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = calculate_expected(7, 13)
    print(f"Test 3: l=7, r=13 => result={result}, expected={expected}")
    if result != expected:
        raise TestFailure(f"Test 3 failed: got {result}, expected {expected}")
    
    # Edge case 4: l=1, r=1 (single odd number)
    dut.l.value = 1
    dut.r.value = 1
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = calculate_expected(1, 1)
    print(f"Test 4: l=1, r=1 => result={result}, expected={expected}")
    if result != expected:
        raise TestFailure(f"Test 4 failed: got {result}, expected {expected}")
    
    # Edge case 5: l=0, r=255 (full range)
    dut.l.value = 0
    dut.r.value = 255
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = calculate_expected(0, 255)
    print(f"Test 5: l=0, r=255 => result={result}, expected={expected}")
    if result != expected:
        raise TestFailure(f"Test 5 failed: got {result}, expected {expected}")
    
    # Edge case 6: l=100, r=100 (even number range, should be 0)
    dut.l.value = 100
    dut.r.value = 100
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = calculate_expected(100, 100)
    print(f"Test 6: l=100, r=100 => result={result}, expected={expected}")
    if result != expected:
        raise TestFailure(f"Test 6 failed: got {result}, expected {expected}")
    
    # Edge case 7: l=254, r=255
    dut.l.value = 254
    dut.r.value = 255
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = calculate_expected(254, 255)
    print(f"Test 7: l=254, r=255 => result={result}, expected={expected}")
    if result != expected:
        raise TestFailure(f"Test 7 failed: got {result}, expected {expected}")
    
    print("
All 7 tests passed!")
