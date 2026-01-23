import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_count_samepair(dut):
    """Test count_samepair module with multiple test cases"""
    
    # Test Case 1: Expected result = 3
    dut.list1[0] = 1
    dut.list1[1] = 2
    dut.list1[2] = 3
    dut.list1[3] = 4
    dut.list1[4] = 5
    dut.list1[5] = 6
    dut.list1[6] = 7
    dut.list1[7] = 8
    
    dut.list2[0] = 2
    dut.list2[1] = 2
    dut.list2[2] = 3
    dut.list2[3] = 1
    dut.list2[4] = 2
    dut.list2[5] = 6
    dut.list2[6] = 7
    dut.list2[7] = 9
    
    dut.list3[0] = 2
    dut.list3[1] = 1
    dut.list3[2] = 3
    dut.list3[3] = 1
    dut.list3[4] = 2
    dut.list3[5] = 6
    dut.list3[6] = 7
    dut.list3[7] = 9
    
    await Timer(10, units='ns')
    result = int(dut.result)
    if result != 3:
        raise TestFailure(f"Test 1 failed: expected 3, got {result}")
    print(f"Test 1 passed: result = {result}")
    
    # Test Case 2: Expected result = 4
    dut.list1[0] = 1
    dut.list1[1] = 2
    dut.list1[2] = 3
    dut.list1[3] = 4
    dut.list1[4] = 5
    dut.list1[5] = 6
    dut.list1[6] = 7
    dut.list1[7] = 8
    
    dut.list2[0] = 2
    dut.list2[1] = 2
    dut.list2[2] = 3
    dut.list2[3] = 1
    dut.list2[4] = 2
    dut.list2[5] = 6
    dut.list2[6] = 7
    dut.list2[7] = 8
    
    dut.list3[0] = 2
    dut.list3[1] = 1
    dut.list3[2] = 3
    dut.list3[3] = 1
    dut.list3[4] = 2
    dut.list3[5] = 6
    dut.list3[6] = 7
    dut.list3[7] = 8
    
    await Timer(10, units='ns')
    result = int(dut.result)
    if result != 4:
        raise TestFailure(f"Test 2 failed: expected 4, got {result}")
    print(f"Test 2 passed: result = {result}")
    
    # Test Case 3: Expected result = 5
    dut.list1[0] = 1
    dut.list1[1] = 2
    dut.list1[2] = 3
    dut.list1[3] = 4
    dut.list1[4] = 2
    dut.list1[5] = 6
    dut.list1[6] = 7
    dut.list1[7] = 8
    
    dut.list2[0] = 2
    dut.list2[1] = 2
    dut.list2[2] = 3
    dut.list2[3] = 1
    dut.list2[4] = 2
    dut.list2[5] = 6
    dut.list2[6] = 7
    dut.list2[7] = 8
    
    dut.list3[0] = 2
    dut.list3[1] = 1
    dut.list3[2] = 3
    dut.list3[3] = 1
    dut.list3[4] = 2
    dut.list3[5] = 6
    dut.list3[6] = 7
    dut.list3[7] = 8
    
    await Timer(10, units='ns')
    result = int(dut.result)
    if result != 5:
        raise TestFailure(f"Test 3 failed: expected 5, got {result}")
    print(f"Test 3 passed: result = {result}")
    
    # Edge Case: No matches
    for i in range(8):
        dut.list1[i] = i + 1
        dut.list2[i] = i + 10
        dut.list3[i] = i + 20
    
    await Timer(10, units='ns')
    result = int(dut.result)
    if result != 0:
        raise TestFailure(f"Edge case failed: expected 0, got {result}")
    print(f"Edge case (no matches) passed: result = {result}")
    
    # Edge Case: All matches
    for i in range(8):
        dut.list1[i] = 42
        dut.list2[i] = 42
        dut.list3[i] = 42
    
    await Timer(10, units='ns')
    result = int(dut.result)
    if result != 8:
        raise TestFailure(f"Edge case failed: expected 8, got {result}")
    print(f"Edge case (all matches) passed: result = {result}")
    
    print("
All tests passed!")