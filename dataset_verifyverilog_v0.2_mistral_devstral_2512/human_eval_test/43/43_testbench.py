import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_pairs_sum_to_zero(dut):
    """Test pairs_sum_to_zero module with various test cases"""
    
    # Test case 1: [1, 3, 5, 0] - should return False
    dut.elements_0.value = 1
    dut.elements_1.value = 3
    dut.elements_2.value = 5
    dut.elements_3.value = 0
    dut.elements_4.value = 0
    dut.elements_5.value = 0
    dut.elements_6.value = 0
    dut.elements_7.value = 0
    dut.valid_count.value = 4
    await Timer(10, units='ns')
    assert dut.result.value == 0, "Test 1 failed: [1,3,5,0] should return False"
    print("Test 1 passed: [1,3,5,0] = False")
    
    # Test case 2: [1, 3, -2, 1] - should return False
    dut.elements_0.value = 1
    dut.elements_1.value = 3
    dut.elements_2.value = -2 & 0xFF  # -2 in 8-bit signed
    dut.elements_3.value = 1
    dut.elements_4.value = 0
    dut.elements_5.value = 0
    dut.elements_6.value = 0
    dut.elements_7.value = 0
    dut.valid_count.value = 4
    await Timer(10, units='ns')
    assert dut.result.value == 0, "Test 2 failed: [1,3,-2,1] should return False"
    print("Test 2 passed: [1,3,-2,1] = False")
    
    # Test case 3: [1, 2, 3, 7] - should return False
    dut.elements_0.value = 1
    dut.elements_1.value = 2
    dut.elements_2.value = 3
    dut.elements_3.value = 7
    dut.elements_4.value = 0
    dut.elements_5.value = 0
    dut.elements_6.value = 0
    dut.elements_7.value = 0
    dut.valid_count.value = 4
    await Timer(10, units='ns')
    assert dut.result.value == 0, "Test 3 failed: [1,2,3,7] should return False"
    print("Test 3 passed: [1,2,3,7] = False")
    
    # Test case 4: [2, 4, -5, 3, 5, 7] - should return True (-5 + 5 = 0)
    dut.elements_0.value = 2
    dut.elements_1.value = 4
    dut.elements_2.value = -5 & 0xFF  # -5 in 8-bit signed
    dut.elements_3.value = 3
    dut.elements_4.value = 5
    dut.elements_5.value = 7
    dut.elements_6.value = 0
    dut.elements_7.value = 0
    dut.valid_count.value = 6
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 4 failed: [2,4,-5,3,5,7] should return True"
    print("Test 4 passed: [2,4,-5,3,5,7] = True")
    
    # Test case 5: [1] - should return False (only one element)
    dut.elements_0.value = 1
    dut.elements_1.value = 0
    dut.elements_2.value = 0
    dut.elements_3.value = 0
    dut.elements_4.value = 0
    dut.elements_5.value = 0
    dut.elements_6.value = 0
    dut.elements_7.value = 0
    dut.valid_count.value = 1
    await Timer(10, units='ns')
    assert dut.result.value == 0, "Test 5 failed: [1] should return False"
    print("Test 5 passed: [1] = False")
    
    # Test case 6: [-3, 9, -1, 3, 2, 30] - should return True (-3 + 3 = 0)
    dut.elements_0.value = -3 & 0xFF
    dut.elements_1.value = 9
    dut.elements_2.value = -1 & 0xFF
    dut.elements_3.value = 3
    dut.elements_4.value = 2
    dut.elements_5.value = 30
    dut.elements_6.value = 0
    dut.elements_7.value = 0
    dut.valid_count.value = 6
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 6 failed: [-3,9,-1,3,2,30] should return True"
    print("Test 6 passed: [-3,9,-1,3,2,30] = True")
    
    # Test case 7: [-3, 9, -1, 3, 2, 31] - should return True (-3 + 3 = 0)
    dut.elements_0.value = -3 & 0xFF
    dut.elements_1.value = 9
    dut.elements_2.value = -1 & 0xFF
    dut.elements_3.value = 3
    dut.elements_4.value = 2
    dut.elements_5.value = 31
    dut.elements_6.value = 0
    dut.elements_7.value = 0
    dut.valid_count.value = 6
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 7 failed: [-3,9,-1,3,2,31] should return True"
    print("Test 7 passed: [-3,9,-1,3,2,31] = True")
    
    # Test case 8: [-3, 9, -1, 4, 2, 30] - should return False
    dut.elements_0.value = -3 & 0xFF
    dut.elements_1.value = 9
    dut.elements_2.value = -1 & 0xFF
    dut.elements_3.value = 4
    dut.elements_4.value = 2
    dut.elements_5.value = 30
    dut.elements_6.value = 0
    dut.elements_7.value = 0
    dut.valid_count.value = 6
    await Timer(10, units='ns')
    assert dut.result.value == 0, "Test 8 failed: [-3,9,-1,4,2,30] should return False"
    print("Test 8 passed: [-3,9,-1,4,2,30] = False")
    
    # Test case 9: [-3, 9, -1, 4, 2, 31] - should return False
    dut.elements_0.value = -3 & 0xFF
    dut.elements_1.value = 9
    dut.elements_2.value = -1 & 0xFF
    dut.elements_3.value = 4
    dut.elements_4.value = 2
    dut.elements_5.value = 31
    dut.elements_6.value = 0
    dut.elements_7.value = 0
    dut.valid_count.value = 6
    await Timer(10, units='ns')
    assert dut.result.value == 0, "Test 9 failed: [-3,9,-1,4,2,31] should return False"
    print("Test 9 passed: [-3,9,-1,4,2,31] = False")
    
    print("
All tests passed: 9/9")