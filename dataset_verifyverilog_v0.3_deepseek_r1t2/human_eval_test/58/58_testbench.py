import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper function to check if a value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper function to convert python list to fixed-size array for testbench
def prepare_array(list_data, size=8):
    return list_data + [0] * (size - len(list_data))

@cocotb.test()
async def test_common_elements(dut):
    """Test common_elements module with various inputs"""
    
    # Test cases: (list1, len1, list2, len2, expected_result, expected_len)
    test_cases = [
        ([1, 4, 3, 34, 653, 2, 5], 7, [5, 7, 1, 5, 9, 653, 121], 7, [1, 5, 653], 3),
        ([5, 3, 2, 8], 4, [3, 2], 2, [2, 3], 2),
        ([4, 3, 2, 8], 4, [3, 2, 4], 3, [2, 3, 4], 3),
        ([4, 3, 2, 8], 4, [], 0, [], 0),
        ([1, 1, 2, 2], 4, [2, 3, 3, 4], 4, [2], 1),  # Test duplicates
        ([100, 200, 50], 3, [50, 100, 150], 3, [50, 100], 2)  # Test unsorted inputs
    ]
    
    for i, (l1, len1, l2, len2, expected_list, expected_len) in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}: l1={l1}, l2={l2}")
        
        # Prepare arrays (pad to 8 elements with 0)
        arr1 = prepare_array(l1)
        arr2 = prepare_array(l2)
        
        # Assign inputs
        for j in range(8):
            dut.list1[j].value = arr1[j]
            dut.list2[j].value = arr2[j]
        
        dut.len1.value = len1
        dut.len2.value = len2
        
        # Wait for combinational logic to propagate
        await Timer(50, units='ns')
        
        # Check result length
        if not is_value_defined(dut.result_len.value):
            raise TestFailure(f"Test {i+1}: result_len is undefined (X/Z)")
        
        actual_len = int(dut.result_len.value)
        if actual_len != expected_len:
            raise TestFailure(f"Test {i+1}: Length mismatch. Expected {expected_len}, got {actual_len}")
        
        # Check result array elements
        # Build list of actual results from non-zero entries (or check all valid entries)
        actual_results = []
        for j in range(actual_len):
            if not is_value_defined(dut.result[j].value):
                raise TestFailure(f"Test {i+1}: result[{j}] is undefined")
            val = int(dut.result[j].value)
            actual_results.append(val)
        
        # Verify sorting order
        for j in range(1, len(actual_results)):
            if actual_results[j] < actual_results[j-1]:
                raise TestFailure(f"Test {i+1}: Output not sorted. Found {actual_results[j-1]} before {actual_results[j]}")
        
        # Verify contents
        if sorted(actual_results) != sorted(expected_list):
            raise TestFailure(f"Test {i+1}: Content mismatch. Expected {expected_list}, got {actual_results}")
        
        # Check remaining elements (beyond result_len) should be 0 or ignored
        # (Strictly speaking, only result_len elements are valid, so we don't strictly enforce values beyond that)
        
        dut._log.info(f"Test Case {i+1} passed")
    
    dut._log.info(f"All {len(test_cases)} tests passed")
