import cocotb
from cocotb.triggers import Timer
import random

def calculate_sum(lst):
    return sum(lst)

def find_max_list(lists):
    return max(lists, key=sum)

@cocotb.test()
async def test_max_sum_list(dut):
    """Test max_sum_list module with various inputs"""
    
    # Test case 1: Original test case
    lists1 = [[1,2,3], [4,5,6], [10,11,12], [7,8,9]]
    dut.list_0 <= lists1[0]
    dut.list_1 <= lists1[1]
    dut.list_2 <= lists1[2]
    dut.list_3 <= lists1[3]
    
    await Timer(10, units='ns')
    
    result = [int(dut.max_list[i]) for i in range(3)]
    expected = find_max_list(lists1)
    
    print(f"Test 1: Input lists: {lists1}")
    print(f"  Expected: {expected}")
    print(f"  Got:      {result}")
    assert result == expected, f"Test 1 failed: expected {expected}, got {result}"
    
    # Test case 2: Reverse ordered
    lists2 = [[3,2,1], [6,5,4], [12,11,10], [0,0,0]]
    dut.list_0 <= lists2[0]
    dut.list_1 <= lists2[1]
    dut.list_2 <= lists2[2]
    dut.list_3 <= lists2[3]
    
    await Timer(10, units='ns')
    
    result = [int(dut.max_list[i]) for i in range(3)]
    expected = find_max_list(lists2)
    
    print(f"Test 2: Input lists: {lists2}")
    print(f"  Expected: {expected}")
    print(f"  Got:      {result}")
    assert result == expected, f"Test 2 failed: expected {expected}, got {result}"
    
    # Test case 3: Single list (others should be smaller)
    lists3 = [[2,3,1], [0,0,0], [-1,-1,-1], [-5,-5,-5]]
    dut.list_0 <= lists3[0]
    dut.list_1 <= lists3[1]
    dut.list_2 <= lists3[2]
    dut.list_3 <= lists3[3]
    
    await Timer(10, units='ns')
    
    result = [int(dut.max_list[i]) for i in range(3)]
    expected = find_max_list(lists3)
    
    print(f"Test 3: Input lists: {lists3}")
    print(f"  Expected: {expected}")
    print(f"  Got:      {result}")
    assert result == expected, f"Test 3 failed: expected {expected}, got {result}"
    
    # Test case 4: All same sum, first should win (or any)
    lists4 = [[1,1,1], [2,0,0], [0,2,0], [0,0,2]]
    dut.list_0 <= lists4[0]
    dut.list_1 <= lists4[1]
    dut.list_2 <= lists4[2]
    dut.list_3 <= lists4[3]
    
    await Timer(10, units='ns')
    
    result = [int(dut.max_list[i]) for i in range(3)]
    expected = find_max_list(lists4)
    
    print(f"Test 4: Input lists: {lists4}")
    print(f"  Expected: {expected}")
    print(f"  Got:      {result}")
    assert result == expected, f"Test 4 failed: expected {expected}, got {result}"
    
    # Test case 5: Edge case with negative numbers
    lists5 = [[-1,-2,-3], [-5,-5,-5], [7,7,7], [1,0,-1]]
    dut.list_0 <= lists5[0]
    dut.list_1 <= lists5[1]
    dut.list_2 <= lists5[2]
    dut.list_3 <= lists5[3]
    
    await Timer(10, units='ns')
    
    result = [int(dut.max_list[i]) for i in range(3)]
    expected = find_max_list(lists5)
    
    print(f"Test 5: Input lists: {lists5}")
    print(f"  Expected: {expected}")
    print(f"  Got:      {result}")
    assert result == expected, f"Test 5 failed: expected {expected}, got {result}"
    
    print("
All 5 tests passed!")