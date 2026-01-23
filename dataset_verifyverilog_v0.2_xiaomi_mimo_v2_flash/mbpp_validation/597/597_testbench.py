import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_find_kth(dut):
    """Test find_kth module with various cases"""
    
    # Test case 1: Basic functionality
    dut.k.value = 5
    dut.m.value = 5
    dut.n.value = 4
    arr1_data = [2, 3, 6, 7, 9, 0, 0, 0]
    arr2_data = [1, 4, 8, 10, 0, 0, 0, 0]
    for i in range(8):
        dut.arr1[i].value = arr1_data[i]
        dut.arr2[i].value = arr2_data[i]
    
    await Timer(10, units='ns')
    result = int(dut.kth_element.value)
    print(f"Test 1: k=5, merged sorted should have 6 at position 4. Got: {result}")
    assert result == 6, f"Expected 6, got {result}"
    
    # Test case 2: Different arrays
    dut.k.value = 7
    dut.m.value = 5
    dut.n.value = 7
    arr1_data = [100, 112, 256, 349, 770, 0, 0, 0]
    arr2_data = [72, 86, 113, 119, 265, 445, 892, 0]
    for i in range(8):
        dut.arr1[i].value = arr1_data[i]
        dut.arr2[i].value = arr2_data[i]
    
    await Timer(10, units='ns')
    result = int(dut.kth_element.value)
    print(f"Test 2: k=7, expected 256. Got: {result}")
    assert result == 256, f"Expected 256, got {result}"
    
    # Test case 3
    dut.k.value = 6
    dut.m.value = 5
    dut.n.value = 4
    arr1_data = [3, 4, 7, 8, 10, 0, 0, 0]
    arr2_data = [2, 5, 9, 11, 0, 0, 0, 0]
    for i in range(8):
        dut.arr1[i].value = arr1_data[i]
        dut.arr2[i].value = arr2_data[i]
    
    await Timer(10, units='ns')
    result = int(dut.kth_element.value)
    print(f"Test 3: k=6, expected 8. Got: {result}")
    assert result == 8, f"Expected 8, got {result}"
    
    # Edge case: First element
    dut.k.value = 1
    dut.m.value = 3
    dut.n.value = 2
    arr1_data = [5, 6, 7, 0, 0, 0, 0, 0]
    arr2_data = [1, 2, 0, 0, 0, 0, 0, 0]
    for i in range(8):
        dut.arr1[i].value = arr1_data[i]
        dut.arr2[i].value = arr2_data[i]
    
    await Timer(10, units='ns')
    result = int(dut.kth_element.value)
    print(f"Edge case 1: k=1, expected 1. Got: {result}")
    assert result == 1, f"Expected 1, got {result}"
    
    # Edge case: Last element
    dut.k.value = 5
    dut.m.value = 3
    dut.n.value = 2
    arr1_data = [5, 6, 7, 0, 0, 0, 0, 0]
    arr2_data = [1, 2, 0, 0, 0, 0, 0, 0]
    for i in range(8):
        dut.arr1[i].value = arr1_data[i]
        dut.arr2[i].value = arr2_data[i]
    
    await Timer(10, units='ns')
    result = int(dut.kth_element.value)
    print(f"Edge case 2: k=5 (last), expected 7. Got: {result}")
    assert result == 7, f"Expected 7, got {result}"
    
    # Edge case: One empty array
    dut.k.value = 3
    dut.m.value = 5
    dut.n.value = 0
    arr1_data = [10, 20, 30, 40, 50, 0, 0, 0]
    arr2_data = [0, 0, 0, 0, 0, 0, 0, 0]
    for i in range(8):
        dut.arr1[i].value = arr1_data[i]
        dut.arr2[i].value = arr2_data[i]
    
    await Timer(10, units='ns')
    result = int(dut.kth_element.value)
    print(f"Edge case 3: n=0, k=3, expected 30. Got: {result}")
    assert result == 30, f"Expected 30, got {result}"
    
    print("All tests passed!")
