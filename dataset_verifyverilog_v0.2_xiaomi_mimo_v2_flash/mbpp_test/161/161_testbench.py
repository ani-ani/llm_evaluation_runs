import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_list_filter(dut):
    """Test list filtering with parallel comparisons"""
    
    # Helper function to set list
    def set_list(dut_list, values):
        for i, val in enumerate(values):
            dut_list[i].value = val
    
    # Helper function to set valid mask
    def set_valid(mask_val):
        dut.valid2.value = mask_val
    
    # Helper function to check result
    def check_result(dut_result, dut_valid, expected_values, expected_valid):
        result_valid = int(dut_valid.value)
        if result_valid != expected_valid:
            raise TestFailure(f"Valid mask mismatch: got {bin(result_valid)}, expected {bin(expected_valid)}")
        
        # Check each expected value against valid result slots
        expected_idx = 0
        for i in range(8):
            if (result_valid >> i) & 1:
                if expected_idx >= len(expected_values):
                    raise TestFailure(f"Extra valid result at index {i}: {int(dut_result[i].value)}")
                actual = int(dut_result[i].value)
                expected = expected_values[expected_idx]
                if actual != expected:
                    raise TestFailure(f"Result[{i}] mismatch: got {actual}, expected {expected}")
                expected_idx += 1
        if expected_idx != len(expected_values):
            raise TestFailure(f"Missing expected values: only {expected_idx} valid results")
    
    # Test 1: Remove evens from 1-10
    dut._log.info("Test 1: Remove [2,4,6,8] from [1,2,3,4,5,6,7,8,9,10]")
    set_list(dut.list1, [1,2,3,4,5,6,7,8,9,10])
    set_list(dut.list2, [2,4,6,8,0,0,0,0])
    set_valid(0b11110000)  # First 4 entries valid
    await Timer(1, units='ns')
    # Expected: [1,3,5,7,9,10] -> valid bits 0,1,2,3,4,5
    check_result(dut.result, dut.result_valid, [1,3,5,7,9,10], 0b00111111)
    
    # Test 2: Remove odds from 1-10
    dut._log.info("Test 2: Remove [1,3,5,7] from [1,2,3,4,5,6,7,8,9,10]")
    set_list(dut.list1, [1,2,3,4,5,6,7,8,9,10])
    set_list(dut.list2, [1,3,5,7,0,0,0,0])
    set_valid(0b11110000)
    await Timer(1, units='ns')
    # Expected: [2,4,6,8,9,10]
    check_result(dut.result, dut.result_valid, [2,4,6,8,9,10], 0b00111111)
    
    # Test 3: Remove [5,7] from 1-10
    dut._log.info("Test 3: Remove [5,7] from [1,2,3,4,5,6,7,8,9,10]")
    set_list(dut.list1, [1,2,3,4,5,6,7,8,9,10])
    set_list(dut.list2, [5,7,0,0,0,0,0,0])
    set_valid(0b11000000)
    await Timer(1, units='ns')
    # Expected: [1,2,3,4,6,8,9,10]
    check_result(dut.result, dut.result_valid, [1,2,3,4,6,8,9,10], 0b11111111)
    
    # Test 4: Remove all elements
    dut._log.info("Test 4: Remove all elements")
    set_list(dut.list1, [1,2,3,4,5,6,7,8,0,0])
    set_list(dut.list2, [1,2,3,4,5,6,7,8])
    set_valid(0b11111111)
    await Timer(1, units='ns')
    check_result(dut.result, dut.result_valid, [], 0b00000000)
    
    # Test 5: Remove nothing (empty list2)
    dut._log.info("Test 5: Remove nothing (empty list2)")
    set_list(dut.list1, [1,2,3,4,0,0,0,0])
    set_list(dut.list2, [0,0,0,0,0,0,0,0])
    set_valid(0b00000000)
    await Timer(1, units='ns')
    check_result(dut.result, dut.result_valid, [1,2,3,4], 0b00001111)
    
    dut._log.info("All tests passed!")
