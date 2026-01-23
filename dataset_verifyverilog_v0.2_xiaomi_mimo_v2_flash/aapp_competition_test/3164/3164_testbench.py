import cocotb
from cocotb.triggers import Timer
import random

def calculate_max_even_pairs(arr, n):
    """Calculate max length of subarray where each element appears exactly twice"""
    max_len = 0
    for i in range(n):
        for j in range(i, n):
            subarray = arr[i:j+1]
            freq = {}
            for val in subarray:
                freq[val] = freq.get(val, 0) + 1
            # Check if all elements appear exactly twice
            valid = True
            for count in freq.values():
                if count != 2:
                    valid = False
                    break
            if valid:
                length = j - i + 1
                if length > max_len:
                    max_len = length
    return max_len

@cocotb.test()
async def test_find_max_even_pairs(dut):
    """Test the find_max_even_pairs module with various test cases"""
    
    # Test case 1: [1,2,3,3,4,2] -> expected 2
    dut.n_i.value = 6
    dut.arr_i.value = [1, 2, 3, 3, 4, 2]
    await Timer(10, units='ns')
    result = int(dut.max_length.value)
    expected = 2
    assert result == expected, f"Test 1 failed: expected {expected}, got {result}"
    print(f"Test 1 passed: arr=[1,2,3,3,4,2] -> {result}")
    
    # Test case 2: [1,2,1,3,1,3,1,2] -> expected 4
    dut.n_i.value = 8
    dut.arr_i.value = [1, 2, 1, 3, 1, 3, 1, 2]
    await Timer(10, units='ns')
    result = int(dut.max_length.value)
    expected = 4
    assert result == expected, f"Test 2 failed: expected {expected}, got {result}"
    print(f"Test 2 passed: arr=[1,2,1,3,1,3,1,2] -> {result}")
    
    # Test case 3: [1,10,100,1000,100,10,1] -> expected 0
    dut.n_i.value = 7
    dut.arr_i.value = [1, 10, 100, 1000, 100, 10, 1]
    await Timer(10, units='ns')
    result = int(dut.max_length.value)
    expected = 0
    assert result == expected, f"Test 3 failed: expected {expected}, got {result}"
    print(f"Test 3 passed: arr=[1,10,100,1000,100,10,1] -> {result}")
    
    # Test case 4: [5,5] -> expected 2 (both appear twice)
    dut.n_i.value = 2
    dut.arr_i.value = [5, 5]
    await Timer(10, units='ns')
    result = int(dut.max_length.value)
    expected = 2
    assert result == expected, f"Test 4 failed: expected {expected}, got {result}"
    print(f"Test 4 passed: arr=[5,5] -> {result}")
    
    # Test case 5: [1,2,1,2] -> expected 4 (both appear twice)
    dut.n_i.value = 4
    dut.arr_i.value = [1, 2, 1, 2]
    await Timer(10, units='ns')
    result = int(dut.max_length.value)
    expected = 4
    assert result == expected, f"Test 5 failed: expected {expected}, got {result}"
    print(f"Test 5 passed: arr=[1,2,1,2] -> {result}")
    
    # Test case 6: [1,2,3,4] -> expected 0 (no duplicates)
    dut.n_i.value = 4
    dut.arr_i.value = [1, 2, 3, 4]
    await Timer(10, units='ns')
    result = int(dut.max_length.value)
    expected = 0
    assert result == expected, f"Test 6 failed: expected {expected}, got {result}"
    print(f"Test 6 passed: arr=[1,2,3,4] -> {result}")
    
    # Test case 7: [7,7,7,7] -> expected 0 (appears 4 times, not twice)
    dut.n_i.value = 4
    dut.arr_i.value = [7, 7, 7, 7]
    await Timer(10, units='ns')
    result = int(dut.max_length.value)
    expected = 0
    assert result == expected, f"Test 7 failed: expected {expected}, got {result}"
    print(f"Test 7 passed: arr=[7,7,7,7] -> {result}")
    
    # Test case 8: empty array
    dut.n_i.value = 0
    dut.arr_i.value = [0, 0, 0, 0, 0, 0, 0, 0]
    await Timer(10, units='ns')
    result = int(dut.max_length.value)
    expected = 0
    assert result == expected, f"Test 8 failed: expected {expected}, got {result}"
    print(f"Test 8 passed: arr=[] -> {result}")
    
    print("
=== All tests completed ===")
    print(f"Summary: All 8 tests passed")
