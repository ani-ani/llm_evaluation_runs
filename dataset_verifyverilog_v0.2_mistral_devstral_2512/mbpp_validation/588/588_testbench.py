import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_big_diff(dut):
    """Test big_diff module with various test cases"""
    
    # Test case 1: [1,2,3,4] -> 3
    dut.nums[0] = 1
    dut.nums[1] = 2
    dut.nums[2] = 3
    dut.nums[3] = 4
    dut.nums[4] = 0
    dut.nums[5] = 0
    dut.nums[6] = 0
    dut.nums[7] = 0
    await Timer(10, units='ns')
    assert dut.diff.value == 3, f"Test 1 failed: expected 3, got {dut.diff.value}"
    print("Test 1 passed: [1,2,3,4] -> 3")
    
    # Test case 2: [4,5,12] -> 8
    dut.nums[0] = 4
    dut.nums[1] = 5
    dut.nums[2] = 12
    dut.nums[3] = 0
    dut.nums[4] = 0
    dut.nums[5] = 0
    dut.nums[6] = 0
    dut.nums[7] = 0
    await Timer(10, units='ns')
    assert dut.diff.value == 8, f"Test 2 failed: expected 8, got {dut.diff.value}"
    print("Test 2 passed: [4,5,12] -> 8")
    
    # Test case 3: [9,2,3] -> 7
    dut.nums[0] = 9
    dut.nums[1] = 2
    dut.nums[2] = 3
    dut.nums[3] = 0
    dut.nums[4] = 0
    dut.nums[5] = 0
    dut.nums[6] = 0
    dut.nums[7] = 0
    await Timer(10, units='ns')
    assert dut.diff.value == 7, f"Test 3 failed: expected 7, got {dut.diff.value}"
    print("Test 3 passed: [9,2,3] -> 7")
    
    # Test case 4: all same values [5,5,5,5] -> 0
    dut.nums[0] = 5
    dut.nums[1] = 5
    dut.nums[2] = 5
    dut.nums[3] = 5
    dut.nums[4] = 5
    dut.nums[5] = 5
    dut.nums[6] = 5
    dut.nums[7] = 5
    await Timer(10, units='ns')
    assert dut.diff.value == 0, f"Test 4 failed: expected 0, got {dut.diff.value}"
    print("Test 4 passed: [5,5,5,5] -> 0")
    
    # Test case 5: max value difference [0,255,100] -> 255
    dut.nums[0] = 0
    dut.nums[1] = 255
    dut.nums[2] = 100
    dut.nums[3] = 0
    dut.nums[4] = 0
    dut.nums[5] = 0
    dut.nums[6] = 0
    dut.nums[7] = 0
    await Timer(10, units='ns')
    assert dut.diff.value == 255, f"Test 5 failed: expected 255, got {dut.diff.value}"
    print("Test 5 passed: [0,255,100] -> 255")
    
    print("
5/5 tests passed")