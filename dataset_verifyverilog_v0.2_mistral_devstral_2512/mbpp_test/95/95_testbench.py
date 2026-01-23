import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_find_min_length(dut):
    """Test Find_Min_Length module with various input arrays"""
    
    # Test case 1: [[1],[1,2]] -> min length = 1
    dut.data[0][0] = 1
    dut.data[0][1] = 0
    dut.data[0][2] = 0
    dut.data[0][3] = 0
    dut.data[1][0] = 1
    dut.data[1][1] = 2
    dut.data[1][2] = 0
    dut.data[1][3] = 0
    dut.valid_mask = 0b0011  # First two arrays valid
    
    await Timer(10, units='ns')
    
    if dut.min_length.value != 1:
        raise TestFailure(f"Test 1 failed: expected 1, got {dut.min_length.value}")
    print("Test 1 passed: [[1],[1,2]] -> min length = 1")
    
    # Test case 2: [[1,2],[1,2,3],[1,2,3,4]] -> min length = 2
    dut.data[0][0] = 1
    dut.data[0][1] = 2
    dut.data[0][2] = 0
    dut.data[0][3] = 0
    dut.data[1][0] = 1
    dut.data[1][1] = 2
    dut.data[1][2] = 3
    dut.data[1][3] = 0
    dut.data[2][0] = 1
    dut.data[2][1] = 2
    dut.data[2][2] = 3
    dut.data[2][3] = 4
    dut.valid_mask = 0b0111  # All three arrays valid
    
    await Timer(10, units='ns')
    
    if dut.min_length.value != 2:
        raise TestFailure(f"Test 2 failed: expected 2, got {dut.min_length.value}")
    print("Test 2 passed: [[1,2],[1,2,3],[1,2,3,4]] -> min length = 2")
    
    # Test case 3: [[3,3,3],[4,4,4,4]] -> min length = 3
    dut.data[0][0] = 3
    dut.data[0][1] = 3
    dut.data[0][2] = 3
    dut.data[0][3] = 0
    dut.data[1][0] = 4
    dut.data[1][1] = 4
    dut.data[1][2] = 4
    dut.data[1][3] = 4
    dut.valid_mask = 0b0011  # First two arrays valid
    
    await Timer(10, units='ns')
    
    if dut.min_length.value != 3:
        raise TestFailure(f"Test 3 failed: expected 3, got {dut.min_length.value}")
    print("Test 3 passed: [[3,3,3],[4,4,4,4]] -> min length = 3")
    
    # Edge case: All arrays same length
    dut.data[0][0] = 1
    dut.data[0][1] = 2
    dut.data[0][2] = 0
    dut.data[0][3] = 0
    dut.data[1][0] = 3
    dut.data[1][1] = 4
    dut.data[1][2] = 0
    dut.data[1][3] = 0
    dut.valid_mask = 0b0011
    
    await Timer(10, units='ns')
    
    if dut.min_length.value != 2:
        raise TestFailure(f"Edge case failed: expected 2, got {dut.min_length.value}")
    print("Edge case passed: All arrays same length")
    
    # Single array
    dut.data[0][0] = 5
    dut.data[0][1] = 6
    dut.data[0][2] = 7
    dut.data[0][3] = 8
    dut.data[0][4] = 9
    dut.data[0][5] = 10
    dut.data[0][6] = 0
    dut.data[0][7] = 0
    dut.valid_mask = 0b0001
    
    await Timer(10, units='ns')
    
    if dut.min_length.value != 6:
        raise TestFailure(f"Single array test failed: expected 6, got {dut.min_length.value}")
    print("Single array test passed")
    
    print(f"
All tests passed! Summary: 5/5")