import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_dict_sum(dut):
    """Test dictionary sum functionality with array summation"""
    
    # Test 1: Values 100, 200, 300 -> sum 600
    dut.num_items.value = 3
    dut.values.value = [100, 200, 300, 0, 0, 0, 0, 0]
    await Timer(10, units='ns')
    expected = 600
    actual = int(dut.sum.value)
    if actual != expected:
        raise TestFailure(f"Test 1 failed: expected {expected}, got {actual}")
    print(f"Test 1: Sum = {actual} (expected {expected}) - PASS")
    
    # Test 2: Values 25, 18, 45 -> sum 88
    dut.num_items.value = 3
    dut.values.value = [25, 18, 45, 0, 0, 0, 0, 0]
    await Timer(10, units='ns')
    expected = 88
    actual = int(dut.sum.value)
    if actual != expected:
        raise TestFailure(f"Test 2 failed: expected {expected}, got {actual}")
    print(f"Test 2: Sum = {actual} (expected {expected}) - PASS")
    
    # Test 3: Values 36, 39, 49 -> sum 124
    dut.num_items.value = 3
    dut.values.value = [36, 39, 49, 0, 0, 0, 0, 0]
    await Timer(10, units='ns')
    expected = 124
    actual = int(dut.sum.value)
    if actual != expected:
        raise TestFailure(f"Test 3 failed: expected {expected}, got {actual}")
    print(f"Test 3: Sum = {actual} (expected {expected}) - PASS")
    
    # Test 4: All 8 items
    dut.num_items.value = 8
    dut.values.value = [10, 20, 30, 40, 50, 60, 70, 80]
    await Timer(10, units='ns')
    expected = 360
    actual = int(dut.sum.value)
    if actual != expected:
        raise TestFailure(f"Test 4 failed: expected {expected}, got {actual}")
    print(f"Test 4: Sum = {actual} (expected {expected}) - PASS")
    
    # Test 5: Single item
    dut.num_items.value = 1
    dut.values.value = [999, 0, 0, 0, 0, 0, 0, 0]
    await Timer(10, units='ns')
    expected = 999
    actual = int(dut.sum.value)
    if actual != expected:
        raise TestFailure(f"Test 5 failed: expected {expected}, got {actual}")
    print(f"Test 5: Sum = {actual} (expected {expected}) - PASS")
    
    # Test 6: Zero items
    dut.num_items.value = 0
    dut.values.value = [123, 456, 789, 0, 0, 0, 0, 0]
    await Timer(10, units='ns')
    expected = 0
    actual = int(dut.sum.value)
    if actual != expected:
        raise TestFailure(f"Test 6 failed: expected {expected}, got {actual}")
    print(f"Test 6: Sum = {actual} (expected {expected}) - PASS")
    
    print("
All 6 tests passed!")