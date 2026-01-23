import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

def list_difference_reference(list1, list2):
    """Reference implementation in Python"""
    # Remove duplicates from each list while preserving order
    seen1 = set()
    unique1 = []
    for x in list1:
        if x not in seen1:
            seen1.add(x)
            unique1.append(x)
    
    seen2 = set()
    unique2 = []
    for x in list2:
        if x not in seen2:
            seen2.add(x)
            unique2.append(x)
    
    # Compute symmetric difference
    diff1 = [x for x in unique1 if x not in unique2]
    diff2 = [x for x in unique2 if x not in unique1]
    
    result = diff1 + diff2
    # Pad to 16 elements with 255
    while len(result) < 16:
        result.append(255)
    # Truncate if more than 16 (shouldn't happen with 8+8 elements)
    return result[:16]

@cocotb.test()
async def test_list_difference_basic(dut):
    """Test basic symmetric difference"""
    # Test 1: [10, 15, 20, 25, 30, 35, 40] and [25, 40, 35]
    # Expected: [10, 20, 30, 15] + [] = [10, 20, 30, 15, 255, ..., 255]
    dut.list1[0].value = 10
    dut.list1[1].value = 15
    dut.list1[2].value = 20
    dut.list1[3].value = 25
    dut.list1[4].value = 30
    dut.list1[5].value = 35
    dut.list1[6].value = 40
    dut.list1[7].value = 255  # sentinel
    
    dut.list2[0].value = 25
    dut.list2[1].value = 40
    dut.list2[2].value = 35
    dut.list2[3].value = 255
    dut.list2[4].value = 255
    dut.list2[5].value = 255
    dut.list2[6].value = 255
    dut.list2[7].value = 255
    
    await Timer(10, units='ns')
    
    # Check output
    expected = list_difference_reference([10, 15, 20, 25, 30, 35, 40], [25, 40, 35])
    for i in range(16):
        actual = int(dut.difference[i].value)
        if actual != expected[i]:
            raise TestFailure(f"Index {i}: expected {expected[i]}, got {actual}")
    
    dut._log.info("Test 1 passed: Basic difference")

@cocotb.test()
async def test_list_difference_test2(dut):
    """Test second test case"""
    # Test 2: [1,2,3,4,5] and [6,7,1]
    # Expected: [2,3,4,5] + [6,7] = [2,3,4,5,6,7, 255...]
    dut.list1[0].value = 1
    dut.list1[1].value = 2
    dut.list1[2].value = 3
    dut.list1[3].value = 4
    dut.list1[4].value = 5
    dut.list1[5].value = 255
    dut.list1[6].value = 255
    dut.list1[7].value = 255
    
    dut.list2[0].value = 6
    dut.list2[1].value = 7
    dut.list2[2].value = 1
    dut.list2[3].value = 255
    dut.list2[4].value = 255
    dut.list2[5].value = 255
    dut.list2[6].value = 255
    dut.list2[7].value = 255
    
    await Timer(10, units='ns')
    
    expected = list_difference_reference([1,2,3,4,5], [6,7,1])
    for i in range(16):
        actual = int(dut.difference[i].value)
        if actual != expected[i]:
            raise TestFailure(f"Index {i}: expected {expected[i]}, got {actual}")
    
    dut._log.info("Test 2 passed")

@cocotb.test()
async def test_list_difference_test3(dut):
    """Test third test case"""
    # Test 3: [1,2,3] and [6,7,1]
    # Expected: [2,3] + [6,7] = [2,3,6,7, 255...]
    dut.list1[0].value = 1
    dut.list1[1].value = 2
    dut.list1[2].value = 3
    dut.list1[3].value = 255
    dut.list1[4].value = 255
    dut.list1[5].value = 255
    dut.list1[6].value = 255
    dut.list1[7].value = 255
    
    dut.list2[0].value = 6
    dut.list2[1].value = 7
    dut.list2[2].value = 1
    dut.list2[3].value = 255
    dut.list2[4].value = 255
    dut.list2[5].value = 255
    dut.list2[6].value = 255
    dut.list2[7].value = 255
    
    await Timer(10, units='ns')
    
    expected = list_difference_reference([1,2,3], [6,7,1])
    for i in range(16):
        actual = int(dut.difference[i].value)
        if actual != expected[i]:
            raise TestFailure(f"Index {i}: expected {expected[i]}, got {actual}")
    
    dut._log.info("Test 3 passed")

@cocotb.test()
async def test_list_difference_edge_cases(dut):
    """Test edge cases: empty-ish lists, duplicates, all same"""
    # Test: [1,1,2,2] and [2,2,3,3]
    # Expected: [1] + [3] = [1,3, 255...]
    dut.list1[0].value = 1
    dut.list1[1].value = 1
    dut.list1[2].value = 2
    dut.list1[3].value = 2
    dut.list1[4].value = 255
    dut.list1[5].value = 255
    dut.list1[6].value = 255
    dut.list1[7].value = 255
    
    dut.list2[0].value = 2
    dut.list2[1].value = 2
    dut.list2[2].value = 3
    dut.list2[3].value = 3
    dut.list2[4].value = 255
    dut.list2[5].value = 255
    dut.list2[6].value = 255
    dut.list2[7].value = 255
    
    await Timer(10, units='ns')
    
    expected = list_difference_reference([1,1,2,2], [2,2,3,3])
    for i in range(16):
        actual = int(dut.difference[i].value)
        if actual != expected[i]:
            raise TestFailure(f"Index {i}: expected {expected[i]}, got {actual}")
    
    dut._log.info("Test 4 passed: Edge cases with duplicates")

@cocotb.test()
async def test_list_difference_all_same(dut):
    """Test when lists are identical"""
    # Test: [1,2,3,4] and [1,2,3,4]
    # Expected: [] + [] = all 255
    dut.list1[0].value = 1
    dut.list1[1].value = 2
    dut.list1[2].value = 3
    dut.list1[3].value = 4
    dut.list1[4].value = 255
    dut.list1[5].value = 255
    dut.list1[6].value = 255
    dut.list1[7].value = 255
    
    dut.list2[0].value = 1
    dut.list2[1].value = 2
    dut.list2[2].value = 3
    dut.list2[3].value = 4
    dut.list2[4].value = 255
    dut.list2[5].value = 255
    dut.list2[6].value = 255
    dut.list2[7].value = 255
    
    await Timer(10, units='ns')
    
    expected = list_difference_reference([1,2,3,4], [1,2,3,4])
    for i in range(16):
        actual = int(dut.difference[i].value)
        if actual != expected[i]:
            raise TestFailure(f"Index {i}: expected {expected[i]}, got {actual}")
    
    dut._log.info("Test 5 passed: All same")
