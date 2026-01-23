import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_below_threshold(dut):
    """Test below_threshold module with various inputs"""
    
    # Test case 1: All below threshold
    dut.threshold.value = 100
    dut.array[0].value = 1
    dut.array[1].value = 2
    dut.array[2].value = 4
    dut.array[3].value = 10
    dut.array[4].value = 0
    dut.array[5].value = 0
    dut.array[6].value = 0
    dut.array[7].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 1 failed: Expected True for [1,2,4,10] < 100"
    
    # Test case 2: Some above threshold
    dut.threshold.value = 5
    dut.array[0].value = 1
    dut.array[1].value = 20
    dut.array[2].value = 4
    dut.array[3].value = 10
    dut.array[4].value = 0
    dut.array[5].value = 0
    dut.array[6].value = 0
    dut.array[7].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 0, "Test 2 failed: Expected False for [1,20,4,10] >= 5"
    
    # Test case 3: Borderline case - all below
    dut.threshold.value = 21
    dut.array[0].value = 1
    dut.array[1].value = 20
    dut.array[2].value = 4
    dut.array[3].value = 10
    dut.array[4].value = 0
    dut.array[5].value = 0
    dut.array[6].value = 0
    dut.array[7].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 3 failed: Expected True for [1,20,4,10] < 21"
    
    # Test case 4: Borderline case - all below
    dut.threshold.value = 22
    dut.array[0].value = 1
    dut.array[1].value = 20
    dut.array[2].value = 4
    dut.array[3].value = 10
    dut.array[4].value = 0
    dut.array[5].value = 0
    dut.array[6].value = 0
    dut.array[7].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 4 failed: Expected True for [1,20,4,10] < 22"
    
    # Test case 5: All below threshold
    dut.threshold.value = 11
    dut.array[0].value = 1
    dut.array[1].value = 8
    dut.array[2].value = 4
    dut.array[3].value = 10
    dut.array[4].value = 0
    dut.array[5].value = 0
    dut.array[6].value = 0
    dut.array[7].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 5 failed: Expected True for [1,8,4,10] < 11"
    
    # Test case 6: Borderline - element equals threshold
    dut.threshold.value = 10
    dut.array[0].value = 1
    dut.array[1].value = 8
    dut.array[2].value = 4
    dut.array[3].value = 10
    dut.array[4].value = 0
    dut.array[5].value = 0
    dut.array[6].value = 0
    dut.array[7].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 0, "Test 6 failed: Expected False for [1,8,4,10] with element equal to threshold"
    
    # Test case 7: All elements equal to threshold
    dut.threshold.value = 5
    dut.array[0].value = 5
    dut.array[1].value = 5
    dut.array[2].value = 5
    dut.array[3].value = 5
    dut.array[4].value = 0
    dut.array[5].value = 0
    dut.array[6].value = 0
    dut.array[7].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 0, "Test 7 failed: Expected False when elements equal threshold"
    
    # Test case 8: Maximum threshold (255)
    dut.threshold.value = 255
    dut.array[0].value = 254
    dut.array[1].value = 200
    dut.array[2].value = 100
    dut.array[3].value = 50
    dut.array[4].value = 0
    dut.array[5].value = 0
    dut.array[6].value = 0
    dut.array[7].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 8 failed: Expected True for all below 255"
    
    # Test case 9: Minimum threshold (0)
    dut.threshold.value = 0
    dut.array[0].value = 0
    dut.array[1].value = 1
    dut.array[2].value = 2
    dut.array[3].value = 3
    dut.array[4].value = 0
    dut.array[5].value = 0
    dut.array[6].value = 0
    dut.array[7].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 0, "Test 9 failed: Expected False when threshold is 0"
    
    print(f"All tests passed!")