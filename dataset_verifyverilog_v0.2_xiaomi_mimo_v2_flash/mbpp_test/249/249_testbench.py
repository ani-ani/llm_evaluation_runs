import cocotb
from cocotb.triggers import Timer
import random

def python_intersection(arr1, arr2):
    """Python reference implementation"""
    return list(filter(lambda x: x in arr1, arr2))

@cocotb.test()
async def test_array_intersection(dut):
    """Test array intersection module with various cases"""
    
    # Test case 1: From original problem
    dut.array1[0].value = 1
    dut.array1[1].value = 2
    dut.array1[2].value = 3
    dut.array1[3].value = 5
    dut.array1[4].value = 7
    dut.array1[5].value = 8
    dut.array1[6].value = 9
    dut.array1[7].value = 10
    dut.len1.value = 8
    
    dut.array2[0].value = 1
    dut.array2[1].value = 2
    dut.array2[2].value = 4
    dut.array2[3].value = 8
    dut.array2[4].value = 9
    dut.array2[5].value = 0
    dut.array2[6].value = 0
    dut.array2[7].value = 0
    dut.len2.value = 5
    
    await Timer(10, units='ns')
    
    # Check result
    valid_mask = int(dut.result_valid.value)
    result = []
    for i in range(8):
        if valid_mask & (1 << i):
            result.append(int(dut.result[i].value))
    
    expected = python_intersection([1,2,3,5,7,8,9,10], [1,2,4,8,9])
    dut._log.info(f"Test 1: Result={result}, Expected={expected}")
    assert result == expected, f"Test 1 failed: got {result}, expected {expected}"
    
    # Test case 2
    dut.array1[0].value = 1
    dut.array1[1].value = 2
    dut.array1[2].value = 3
    dut.array1[3].value = 5
    dut.array1[4].value = 7
    dut.array1[5].value = 8
    dut.array1[6].value = 9
    dut.array1[7].value = 10
    dut.len1.value = 8
    
    dut.array2[0].value = 3
    dut.array2[1].value = 5
    dut.array2[2].value = 7
    dut.array2[3].value = 9
    dut.array2[4].value = 0
    dut.array2[5].value = 0
    dut.array2[6].value = 0
    dut.array2[7].value = 0
    dut.len2.value = 4
    
    await Timer(10, units='ns')
    
    valid_mask = int(dut.result_valid.value)
    result = []
    for i in range(8):
        if valid_mask & (1 << i):
            result.append(int(dut.result[i].value))
    
    expected = python_intersection([1,2,3,5,7,8,9,10], [3,5,7,9])
    dut._log.info(f"Test 2: Result={result}, Expected={expected}")
    assert result == expected, f"Test 2 failed: got {result}, expected {expected}"
    
    # Test case 3
    dut.array1[0].value = 1
    dut.array1[1].value = 2
    dut.array1[2].value = 3
    dut.array1[3].value = 5
    dut.array1[4].value = 7
    dut.array1[5].value = 8
    dut.array1[6].value = 9
    dut.array1[7].value = 10
    dut.len1.value = 8
    
    dut.array2[0].value = 10
    dut.array2[1].value = 20
    dut.array2[2].value = 30
    dut.array2[3].value = 40
    dut.array2[4].value = 0
    dut.array2[5].value = 0
    dut.array2[6].value = 0
    dut.array2[7].value = 0
    dut.len2.value = 4
    
    await Timer(10, units='ns')
    
    valid_mask = int(dut.result_valid.value)
    result = []
    for i in range(8):
        if valid_mask & (1 << i):
            result.append(int(dut.result[i].value))
    
    expected = python_intersection([1,2,3,5,7,8,9,10], [10,20,30,40])
    dut._log.info(f"Test 3: Result={result}, Expected={expected}")
    assert result == expected, f"Test 3 failed: got {result}, expected {expected}"
    
    # Test case 4: Empty array
    dut.len1.value = 0
    dut.len2.value = 3
    dut.array2[0].value = 1
    dut.array2[1].value = 2
    dut.array2[2].value = 3
    
    await Timer(10, units='ns')
    
    valid_mask = int(dut.result_valid.value)
    assert valid_mask == 0, f"Test 4 failed: empty array1 should produce no results"
    dut._log.info("Test 4 passed: Empty array1")
    
    # Test case 5: All elements match
    dut.array1[0].value = 5
    dut.array1[1].value = 10
    dut.array1[2].value = 15
    dut.array1[3].value = 0
    dut.array1[4].value = 0
    dut.array1[5].value = 0
    dut.array1[6].value = 0
    dut.array1[7].value = 0
    dut.len1.value = 3
    
    dut.array2[0].value = 15
    dut.array2[1].value = 5
    dut.array2[2].value = 10
    dut.array2[3].value = 0
    dut.array2[4].value = 0
    dut.array2[5].value = 0
    dut.array2[6].value = 0
    dut.array2[7].value = 0
    dut.len2.value = 3
    
    await Timer(10, units='ns')
    
    valid_mask = int(dut.result_valid.value)
    result = []
    for i in range(8):
        if valid_mask & (1 << i):
            result.append(int(dut.result[i].value))
    
    expected = python_intersection([5,10,15], [15,5,10])
    dut._log.info(f"Test 5: Result={result}, Expected={expected}")
    assert result == expected, f"Test 5 failed: got {result}, expected {expected}"
    
    # Test case 6: Duplicates in array2
    dut.array1[0].value = 1
    dut.array1[1].value = 2
    dut.array1[2].value = 3
    dut.array1[3].value = 0
    dut.array1[4].value = 0
    dut.array1[5].value = 0
    dut.array1[6].value = 0
    dut.array1[7].value = 0
    dut.len1.value = 3
    
    dut.array2[0].value = 2
    dut.array2[1].value = 2
    dut.array2[2].value = 1
    dut.array2[3].value = 0
    dut.array2[4].value = 0
    dut.array2[5].value = 0
    dut.array2[6].value = 0
    dut.array2[7].value = 0
    dut.len2.value = 3
    
    await Timer(10, units='ns')
    
    valid_mask = int(dut.result_valid.value)
    result = []
    for i in range(8):
        if valid_mask & (1 << i):
            result.append(int(dut.result[i].value))
    
    expected = python_intersection([1,2,3], [2,2,1])
    dut._log.info(f"Test 6: Result={result}, Expected={expected}")
    assert result == expected, f"Test 6 failed: got {result}, expected {expected}"
    
    dut._log.info("All 6 tests passed!")
