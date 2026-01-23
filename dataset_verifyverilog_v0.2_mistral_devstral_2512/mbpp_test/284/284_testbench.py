import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_check_element(dut):
    """Test if all elements in array match the given element"""
    
    # Test 1: All elements match (should return True/1)
    dut.element_to_match.value = ord('g')  # 'g' in ASCII
    dut.array_data[0].value = ord('g')
    dut.array_data[1].value = ord('g')
    dut.array_data[2].value = ord('g')
    dut.array_data[3].value = ord('g')
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 1 Failed: Expected all elements to match"
    print("Test 1 Passed: All 'g' elements match 'g'")
    
    # Test 2: Some elements don't match (should return False/0)
    dut.element_to_match.value = ord('b')  # 'b' in ASCII
    dut.array_data[0].value = ord('g')
    dut.array_data[1].value = ord('o')
    dut.array_data[2].value = ord('b')
    dut.array_data[3].value = ord('w')
    await Timer(10, units='ns')
    assert dut.result.value == 0, "Test 2 Failed: Expected elements not to match"
    print("Test 2 Passed: Mixed elements don't match 'b'")
    
    # Test 3: Integer test - all match (should return True/1)
    dut.element_to_match.value = 7
    dut.array_data[0].value = 7
    dut.array_data[1].value = 7
    dut.array_data[2].value = 7
    dut.array_data[3].value = 7
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 3 Failed: Expected all integers to match"
    print("Test 3 Passed: All 7s match 7")
    
    # Test 4: Integer test - no match (should return False/0)
    dut.element_to_match.value = 7
    dut.array_data[0].value = 1
    dut.array_data[1].value = 2
    dut.array_data[2].value = 3
    dut.array_data[3].value = 4
    await Timer(10, units='ns')
    assert dut.result.value == 0, "Test 4 Failed: Expected integers not to match"
    print("Test 4 Passed: [1,2,3,4] don't match 7")
    
    # Test 5: Edge case - all zeros
    dut.element_to_match.value = 0
    dut.array_data[0].value = 0
    dut.array_data[1].value = 0
    dut.array_data[2].value = 0
    dut.array_data[3].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 5 Failed: Expected all zeros to match"
    print("Test 5 Passed: All zeros match zero")
    
    # Test 6: Edge case - maximum value
    dut.element_to_match.value = 255
    dut.array_data[0].value = 255
    dut.array_data[1].value = 255
    dut.array_data[2].value = 255
    dut.array_data[3].value = 255
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 6 Failed: Expected all max values to match"
    print("Test 6 Passed: All 255s match 255")
    
    # Summary
    print("
=== All 6 tests passed ===")