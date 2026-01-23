import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_is_even_basic(dut):
    """Test basic even/odd detection"""
    # Test 1: is_Even(1) should return False
    dut.n.value = 1
    await Timer(10, units='ns')
    if dut.is_even.value != 0:
        raise TestFailure(f"is_Even(1) failed: expected 0, got {dut.is_even.value}")
    print(f"Test 1 passed: is_Even(1) = {dut.is_even.value} (False)")
    
    # Test 2: is_Even(2) should return True
    dut.n.value = 2
    await Timer(10, units='ns')
    if dut.is_even.value != 1:
        raise TestFailure(f"is_Even(2) failed: expected 1, got {dut.is_even.value}")
    print(f"Test 2 passed: is_Even(2) = {dut.is_even.value} (True)")
    
    # Test 3: is_Even(3) should return False
    dut.n.value = 3
    await Timer(10, units='ns')
    if dut.is_even.value != 0:
        raise TestFailure(f"is_Even(3) failed: expected 0, got {dut.is_even.value}")
    print(f"Test 3 passed: is_Even(3) = {dut.is_even.value} (False)")
    
    print("
All 3 tests passed!")

@cocotb.test()
async def test_is_even_edge_cases(dut):
    """Test edge cases: zero, max value, powers of 2"""
    # Test zero (even)
    dut.n.value = 0
    await Timer(10, units='ns')
    if dut.is_even.value != 1:
        raise TestFailure(f"is_Even(0) failed: expected 1, got {dut.is_even.value}")
    print(f"Edge case 1 passed: is_Even(0) = {dut.is_even.value}")
    
    # Test 255 (odd)
    dut.n.value = 255
    await Timer(10, units='ns')
    if dut.is_even.value != 0:
        raise TestFailure(f"is_Even(255) failed: expected 0, got {dut.is_even.value}")
    print(f"Edge case 2 passed: is_Even(255) = {dut.is_even.value}")
    
    # Test 254 (even)
    dut.n.value = 254
    await Timer(10, units='ns')
    if dut.is_even.value != 1:
        raise TestFailure(f"is_Even(254) failed: expected 1, got {dut.is_even.value}")
    print(f"Edge case 3 passed: is_Even(254) = {dut.is_even.value}")
    
    # Test 128 (even, power of 2)
    dut.n.value = 128
    await Timer(10, units='ns')
    if dut.is_even.value != 1:
        raise TestFailure(f"is_Even(128) failed: expected 1, got {dut.is_even.value}")
    print(f"Edge case 4 passed: is_Even(128) = {dut.is_even.value}")
    
    print("
All edge case tests passed!")