import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_remove_duplicates(dut):
    """Test remove_duplicates module with various test cases"""
    
    # Helper function to set input array
    def set_input(data):
        for i in range(8):
            if i < len(data):
                dut.data_in[i].value = data[i]
            else:
                dut.data_in[i].value = 255  # Sentinel for unused
    
    # Helper function to get output array
    def get_output():
        result = []
        for i in range(8):
            val = int(dut.data_out[i].value)
            if val != 255:  # Skip sentinel values
                result.append(val)
        return result
    
    # Test case 1: Empty array
    dut._log.info("Test 1: Empty array")
    set_input([])
    await Timer(10, units='ns')
    result = get_output()
    assert result == [], f"Expected [], got {result}"
    
    # Test case 2: No duplicates
    dut._log.info("Test 2: No duplicates [1, 2, 3, 4]")
    set_input([1, 2, 3, 4])
    await Timer(10, units='ns')
    result = get_output()
    assert result == [1, 2, 3, 4], f"Expected [1, 2, 3, 4], got {result}"
    
    # Test case 3: Multiple duplicates
    dut._log.info("Test 3: Multiple duplicates [1, 2, 3, 2, 4, 3, 5]")
    set_input([1, 2, 3, 2, 4, 3, 5])
    await Timer(10, units='ns')
    result = get_output()
    assert result == [1, 2, 3, 4, 5], f"Expected [1, 2, 3, 4, 5], got {result}"
    
    # Test case 4: All duplicates
    dut._log.info("Test 4: All duplicates [1, 1, 1, 1]")
    set_input([1, 1, 1, 1])
    await Timer(10, units='ns')
    result = get_output()
    assert result == [1], f"Expected [1], got {result}"
    
    # Test case 5: Different duplicates
    dut._log.info("Test 5: Different duplicates [5, 3, 5, 3, 2]")
    set_input([5, 3, 5, 3, 2])
    await Timer(10, units='ns')
    result = get_output()
    assert result == [5, 3, 2], f"Expected [5, 3, 2], got {result}"
    
    # Test case 6: Original example
    dut._log.info("Test 6: Original example [1, 2, 3, 2, 4]")
    set_input([1, 2, 3, 2, 4])
    await Timer(10, units='ns')
    result = get_output()
    assert result == [1, 2, 3, 4], f"Expected [1, 2, 3, 4], got {result}"
    
    dut._log.info("All 6 tests passed!")
