import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_unique_element_check(dut):
    """Test unique_element_check module"""
    
    print("
=== Testing unique_element_check module ===")
    
    # Test 1: All elements are 1 (should return True)
    print("
Test 1: All elements equal to 1")
    arr1 = [1]*8
    for i in range(8):
        dut.arr[i].value = arr1[i]
    await Timer(1, units='ns')
    result1 = int(dut.result.value)
    print(f"Input: {arr1}")
    print(f"Expected: 1, Got: {result1}")
    assert result1 == 1, f"Test 1 failed: expected 1, got {result1}"
    
    # Test 2: Mixed elements [1,2,1,2,...] (should return False)
    print("
Test 2: Mixed elements [1,2,1,2,1,2,1,2]")
    arr2 = [1, 2, 1, 2, 1, 2, 1, 2]
    for i in range(8):
        dut.arr[i].value = arr2[i]
    await Timer(1, units='ns')
    result2 = int(dut.result.value)
    print(f"Input: {arr2}")
    print(f"Expected: 0, Got: {result2}")
    assert result2 == 0, f"Test 2 failed: expected 0, got {result2}"
    
    # Test 3: All elements distinct [1,2,3,4,5,6,7,8] (should return False)
    print("
Test 3: All distinct elements [1,2,3,4,5,6,7,8]")
    arr3 = [1, 2, 3, 4, 5, 6, 7, 8]
    for i in range(8):
        dut.arr[i].value = arr3[i]
    await Timer(1, units='ns')
    result3 = int(dut.result.value)
    print(f"Input: {arr3}")
    print(f"Expected: 0, Got: {result3}")
    assert result3 == 0, f"Test 3 failed: expected 0, got {result3}"
    
    # Test 4: All elements are 255 (max 8-bit value)
    print("
Test 4: All elements equal to 255 (0xFF)")
    arr4 = [255]*8
    for i in range(8):
        dut.arr[i].value = arr4[i]
    await Timer(1, units='ns')
    result4 = int(dut.result.value)
    print(f"Input: {arr4}")
    print(f"Expected: 1, Got: {result4}")
    assert result4 == 1, f"Test 4 failed: expected 1, got {result4}"
    
    # Test 5: All elements are 0
    print("
Test 5: All elements equal to 0")
    arr5 = [0]*8
    for i in range(8):
        dut.arr[i].value = arr5[i]
    await Timer(1, units='ns')
    result5 = int(dut.result.value)
    print(f"Input: {arr5}")
    print(f"Expected: 1, Got: {result5}")
    assert result5 == 1, f"Test 5 failed: expected 1, got {result5}"
    
    # Test 6: Only first element different [5,1,1,1,1,1,1,1] (should return False)
    print("
Test 6: Only first element different [5,1,1,1,1,1,1,1]")
    arr6 = [5, 1, 1, 1, 1, 1, 1, 1]
    for i in range(8):
        dut.arr[i].value = arr6[i]
    await Timer(1, units='ns')
    result6 = int(dut.result.value)
    print(f"Input: {arr6}")
    print(f"Expected: 0, Got: {result6}")
    assert result6 == 0, f"Test 6 failed: expected 0, got {result6}"
    
    # Test 7: Only last element different [1,1,1,1,1,1,1,5] (should return False)
    print("
Test 7: Only last element different [1,1,1,1,1,1,1,5]")
    arr7 = [1, 1, 1, 1, 1, 1, 1, 5]
    for i in range(8):
        dut.arr[i].value = arr7[i]
    await Timer(1, units='ns')
    result7 = int(dut.result.value)
    print(f"Input: {arr7}")
    print(f"Expected: 0, Got: {result7}")
    assert result7 == 0, f"Test 7 failed: expected 0, got {result7}"
    
    print("
=== All tests passed! ===")
    print(f"Summary: 7/7 tests passed")