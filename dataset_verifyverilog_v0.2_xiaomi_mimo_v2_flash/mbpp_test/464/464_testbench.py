import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_check_values_same(dut):
    """Test the check_values_same module with various array configurations"""
    
    # Test Case 1: All values match target (12 == 12)
    dut.target_value.value = 12
    dut.array_values[0].value = 12
    dut.array_values[1].value = 12
    dut.array_values[2].value = 12
    dut.array_values[3].value = 12
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 1 Failed: Expected result=1 (all values 12 match target 12), got {dut.result.value}"
    print("Test 1 Passed: All values match target")
    
    # Test Case 2: Values do NOT match target (12 != 10)
    dut.target_value.value = 10
    dut.array_values[0].value = 12
    dut.array_values[1].value = 12
    dut.array_values[2].value = 12
    dut.array_values[3].value = 12
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 2 Failed: Expected result=0 (values 12 don't match target 10), got {dut.result.value}"
    print("Test 2 Passed: Values don't match target")
    
    # Test Case 3: Values do NOT match target (12 != 5)
    dut.target_value.value = 5
    dut.array_values[0].value = 12
    dut.array_values[1].value = 12
    dut.array_values[2].value = 12
    dut.array_values[3].value = 12
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 3 Failed: Expected result=0 (values 12 don't match target 5), got {dut.result.value}"
    print("Test 3 Passed: Values don't match target")
    
    # Test Case 4: Edge case - all zeros match zero
    dut.target_value.value = 0
    dut.array_values[0].value = 0
    dut.array_values[1].value = 0
    dut.array_values[2].value = 0
    dut.array_values[3].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 4 Failed: Expected result=1 (all zeros match zero), got {dut.result.value}"
    print("Test 4 Passed: Zero values match zero target")
    
    # Test Case 5: Mixed values - one different
    dut.target_value.value = 100
    dut.array_values[0].value = 100
    dut.array_values[1].value = 100
    dut.array_values[2].value = 100
    dut.array_values[3].value = 99  # One different
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 5 Failed: Expected result=0 (one value differs), got {dut.result.value}"
    print("Test 5 Passed: Mixed values correctly identified as non-matching")
    
    # Test Case 6: Edge case - maximum values
    dut.target_value.value = 255
    dut.array_values[0].value = 255
    dut.array_values[1].value = 255
    dut.array_values[2].value = 255
    dut.array_values[3].value = 255
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 6 Failed: Expected result=1 (all 255s match), got {dut.result.value}"
    print("Test 6 Passed: Maximum values match")
    
    print("
=== Summary: 6/6 tests passed ===")