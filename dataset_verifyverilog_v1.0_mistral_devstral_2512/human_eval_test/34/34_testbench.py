import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_unique_sorter(dut):
    """Test the unique_sorter module with various inputs."""
    
    # Test cases: (input_list, expected_output_list)
    test_cases = [
        # Original test case
        ([5, 3, 5, 2, 3, 3, 9, 0], [0, 2, 3, 5, 9, 0, 0, 0]),
        # All unique, already sorted
        ([1, 2, 3, 4, 5, 6, 7, 8], [1, 2, 3, 4, 5, 6, 7, 8]),
        # All unique, reverse sorted
        ([8, 7, 6, 5, 4, 3, 2, 1], [1, 2, 3, 4, 5, 6, 7, 8]),
        # All duplicates
        ([5, 5, 5, 5, 5, 5, 5, 5], [5, 0, 0, 0, 0, 0, 0, 0]),
        # Mixed with zeros
        ([0, 0, 1, 1, 2, 2, 3, 3], [0, 1, 2, 3, 0, 0, 0, 0]),
        # Large values
        ([65535, 32768, 100, 200, 65535, 32768, 0, 1], [0, 1, 100, 200, 32768, 65535, 0, 0]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_list, expected_list) in enumerate(test_cases):
        # Apply input: assign each element to dut.numbers[i]
        for j, val in enumerate(input_list):
            dut.numbers[j].value = val
        
        # Wait for combinational logic to propagate
        await Timer(50, units='ns')
        
        # Read and verify outputs
        result_list = []
        all_defined = True
        for j in range(8):
            if not is_value_defined(dut.result[j].value):
                all_defined = False
                break
            result_list.append(int(dut.result[j].value))
        
        if not all_defined:
            dut._log.error(f"Test {i}: Output contains undefined values (X/Z)")
            continue
        
        if result_list == expected_list:
            dut._log.info(f"Test {i}: PASSED - Input: {input_list}, Output: {result_list}")
            passed += 1
        else:
            dut._log.error(f"Test {i}: FAILED")
            dut._log.error(f"  Input:    {input_list}")
            dut._log.error(f"  Expected: {expected_list}")
            dut._log.error(f"  Got:      {result_list}")
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")