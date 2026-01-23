import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import random

@cocotb.test()
async def test_find_max(dut):
    """Test the find_max module with various input patterns"""
    
    # Test cases adapted from original problem
    # Original problem found sublists with max length
    # Adapted: find max element in array of 8 integers
    
    test_cases = [
        # Case 1: Maximum at the end
        ([5, 3, 7, 2, 9, 1, 4, 8], 9),
        # Case 2: Maximum at the beginning
        ([9, 3, 7, 2, 5, 1, 4, 8], 9),
        # Case 3: Maximum in the middle
        ([5, 3, 7, 2, 8, 1, 4, 8], 8),
        # Case 4: All same values
        ([5, 5, 5, 5, 5, 5, 5, 5], 5),
        # Case 5: Maximum value 255
        ([255, 100, 200, 50, 150, 75, 125, 10], 255),
        # Case 6: Minimum value 0
        ([0, 10, 20, 30, 40, 50, 60, 70], 70),
        # Case 7: Powers of 2
        ([1, 2, 4, 8, 16, 32, 64, 128], 128),
        # Case 8: Random pattern
        ([17, 42, 99, 3, 56, 88, 12, 73], 99),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_array, expected_max) in enumerate(test_cases):
        # Set input values
        for j, val in enumerate(input_array):
            setattr(dut.data_in[j], 'value', val)
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        actual_max = int(dut.max_value.value)
        
        # Check result
        if actual_max == expected_max:
            passed += 1
            print(f"Test {i+1}: PASS - Input={input_array}, Expected={expected_max}, Got={actual_max}")
        else:
            print(f"Test {i+1}: FAIL - Input={input_array}, Expected={expected_max}, Got={actual_max}")
    
    # Edge case: descending order
    setattr(dut.data_in[0], 'value', 128)
    setattr(dut.data_in[1], 'value', 64)
    setattr(dut.data_in[2], 'value', 32)
    setattr(dut.data_in[3], 'value', 16)
    setattr(dut.data_in[4], 'value', 8)
    setattr(dut.data_in[5], 'value', 4)
    setattr(dut.data_in[6], 'value', 2)
    setattr(dut.data_in[7], 'value', 1)
    await Timer(10, units='ns')
    actual_max = int(dut.max_value.value)
    if actual_max == 128:
        passed += 1
        print(f"Test 9: PASS - Descending order, Got={actual_max}")
    else:
        print(f"Test 9: FAIL - Descending order, Expected=128, Got={actual_max}")
    total += 1
    
    # Edge case: ascending order
    setattr(dut.data_in[0], 'value', 1)
    setattr(dut.data_in[1], 'value', 2)
    setattr(dut.data_in[2], 'value', 4)
    setattr(dut.data_in[3], 'value', 8)
    setattr(dut.data_in[4], 'value', 16)
    setattr(dut.data_in[5], 'value', 32)
    setattr(dut.data_in[6], 'value', 64)
    setattr(dut.data_in[7], 'value', 128)
    await Timer(10, units='ns')
    actual_max = int(dut.max_value.value)
    if actual_max == 128:
        passed += 1
        print(f"Test 10: PASS - Ascending order, Got={actual_max}")
    else:
        print(f"Test 10: FAIL - Ascending order, Expected=128, Got={actual_max}")
    total += 1
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Some tests failed: {passed}/{total} passed"
}