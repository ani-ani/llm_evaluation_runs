import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_rotate_right(dut):
    """Test the rotate_right module with various rotation amounts"""
    
    # Test case 1: Rotate by 3 positions
    dut.rotate_amount.value = 3
    dut.data_in[0].value = 1
    dut.data_in[1].value = 2
    dut.data_in[2].value = 3
    dut.data_in[3].value = 4
    dut.data_in[4].value = 5
    dut.data_in[5].value = 6
    dut.data_in[6].value = 7
    dut.data_in[7].value = 8
    await Timer(10, units='ns')
    
    expected = [6, 7, 8, 1, 2, 3, 4, 5]
    for i in range(8):
        assert dut.data_out[i].value == expected[i], f"Test 1 failed at index {i}: expected {expected[i]}, got {int(dut.data_out[i].value)}"
    print("Test 1 passed: rotate [1,2,3,4,5,6,7,8] by 3 -> [6,7,8,1,2,3,4,5]")
    
    # Test case 2: Rotate by 2 positions
    dut.rotate_amount.value = 2
    dut.data_in[0].value = 1
    dut.data_in[1].value = 2
    dut.data_in[2].value = 3
    dut.data_in[3].value = 4
    dut.data_in[4].value = 5
    dut.data_in[5].value = 6
    dut.data_in[6].value = 7
    dut.data_in[7].value = 8
    await Timer(10, units='ns')
    
    expected = [7, 8, 1, 2, 3, 4, 5, 6]
    for i in range(8):
        assert dut.data_out[i].value == expected[i], f"Test 2 failed at index {i}: expected {expected[i]}, got {int(dut.data_out[i].value)}"
    print("Test 2 passed: rotate [1,2,3,4,5,6,7,8] by 2 -> [7,8,1,2,3,4,5,6]")
    
    # Test case 3: Rotate by 5 positions
    dut.rotate_amount.value = 5
    dut.data_in[0].value = 1
    dut.data_in[1].value = 2
    dut.data_in[2].value = 3
    dut.data_in[3].value = 4
    dut.data_in[4].value = 5
    dut.data_in[5].value = 6
    dut.data_in[6].value = 7
    dut.data_in[7].value = 8
    await Timer(10, units='ns')
    
    expected = [4, 5, 6, 7, 8, 1, 2, 3]
    for i in range(8):
        assert dut.data_out[i].value == expected[i], f"Test 3 failed at index {i}: expected {expected[i]}, got {int(dut.data_out[i].value)}"
    print("Test 3 passed: rotate [1,2,3,4,5,6,7,8] by 5 -> [4,5,6,7,8,1,2,3]")
    
    # Test case 4: Rotate by 0 (no rotation)
    dut.rotate_amount.value = 0
    dut.data_in[0].value = 10
    dut.data_in[1].value = 20
    dut.data_in[2].value = 30
    dut.data_in[3].value = 40
    dut.data_in[4].value = 50
    dut.data_in[5].value = 60
    dut.data_in[6].value = 70
    dut.data_in[7].value = 80
    await Timer(10, units='ns')
    
    expected = [10, 20, 30, 40, 50, 60, 70, 80]
    for i in range(8):
        assert dut.data_out[i].value == expected[i], f"Test 4 failed at index {i}: expected {expected[i]}, got {int(dut.data_out[i].value)}"
    print("Test 4 passed: rotate [10,20,30,40,50,60,70,80] by 0 -> no change")
    
    # Test case 5: Rotate by 7 (equivalent to left rotate by 1)
    dut.rotate_amount.value = 7
    dut.data_in[0].value = 1
    dut.data_in[1].value = 2
    dut.data_in[2].value = 3
    dut.data_in[3].value = 4
    dut.data_in[4].value = 5
    dut.data_in[5].value = 6
    dut.data_in[6].value = 7
    dut.data_in[7].value = 8
    await Timer(10, units='ns')
    
    expected = [2, 3, 4, 5, 6, 7, 8, 1]
    for i in range(8):
        assert dut.data_out[i].value == expected[i], f"Test 5 failed at index {i}: expected {expected[i]}, got {int(dut.data_out[i].value)}"
    print("Test 5 passed: rotate [1,2,3,4,5,6,7,8] by 7 -> [2,3,4,5,6,7,8,1]")
    
    print("
All 5/5 tests passed!")