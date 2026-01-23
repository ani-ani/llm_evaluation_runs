import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_check_consecutive(dut):
    """Test the check_consecutive module with various test cases"""
    
    # Test Case 1: Consecutive numbers [1,2,3,4,5,6,7,8]
    # Expected: 1 (true)
    dut.data[0].value = 1
    dut.data[1].value = 2
    dut.data[2].value = 3
    dut.data[3].value = 4
    dut.data[4].value = 5
    dut.data[5].value = 6
    dut.data[6].value = 7
    dut.data[7].value = 8
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 1 failed: expected 1, got {dut.result.value}"
    print("Test 1 passed: [1,2,3,4,5,6,7,8] consecutive")
    
    # Test Case 2: Non-consecutive with gap [1,2,3,5,6,7,8,0]
    # Missing 4, has 0 - Expected: 0 (false)
    dut.data[0].value = 1
    dut.data[1].value = 2
    dut.data[2].value = 3
    dut.data[3].value = 5
    dut.data[4].value = 6
    dut.data[5].value = 7
    dut.data[6].value = 8
    dut.data[7].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 2 failed: expected 0, got {dut.result.value}"
    print("Test 2 passed: [1,2,3,5,6,7,8,0] non-consecutive")
    
    # Test Case 3: Duplicate values [1,2,1,4,5,6,7,8]
    # Has duplicate 1 - Expected: 0 (false)
    dut.data[0].value = 1
    dut.data[1].value = 2
    dut.data[2].value = 1
    dut.data[3].value = 4
    dut.data[4].value = 5
    dut.data[5].value = 6
    dut.data[6].value = 7
    dut.data[7].value = 8
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 3 failed: expected 0, got {dut.result.value}"
    print("Test 3 passed: [1,2,1,4,5,6,7,8] has duplicate")
    
    # Test Case 4: Different consecutive range [10,11,12,13,14,15,16,17]
    # Expected: 1 (true)
    for i in range(8):
        dut.data[i].value = 10 + i
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 4 failed: expected 1, got {dut.result.value}"
    print("Test 4 passed: [10,11,12,13,14,15,16,17] consecutive")
    
    # Test Case 5: Unordered but consecutive [8,1,7,2,6,3,5,4]
    # Expected: 1 (true) - consecutive values but unsorted
    dut.data[0].value = 8
    dut.data[1].value = 1
    dut.data[2].value = 7
    dut.data[3].value = 2
    dut.data[4].value = 6
    dut.data[5].value = 3
    dut.data[6].value = 5
    dut.data[7].value = 4
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 5 failed: expected 1, got {dut.result.value}"
    print("Test 5 passed: [8,1,7,2,6,3,5,4] unordered but consecutive")
    
    # Test Case 6: All same values [5,5,5,5,5,5,5,5]
    # Expected: 0 (false) - duplicates
    for i in range(8):
        dut.data[i].value = 5
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 6 failed: expected 0, got {dut.result.value}"
    print("Test 6 passed: [5,5,5,5,5,5,5,5] all duplicates")
    
    # Test Case 7: Zero range [0,0,0,0,0,0,0,0] (special case)
    # Expected: 0 (false) - duplicates
    for i in range(8):
        dut.data[i].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 7 failed: expected 0, got {dut.result.value}"
    print("Test 7 passed: [0,0,0,0,0,0,0,0] all zeros")
    
    print("
=== Summary: All 7/7 tests passed! ===")