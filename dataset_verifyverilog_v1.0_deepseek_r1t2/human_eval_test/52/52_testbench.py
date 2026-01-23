import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_below_threshold(dut):
    """Test the below_threshold module with various test cases."""
    
    # Test cases: (numbers_list, threshold, expected_result)
    test_cases = [
        ([1, 2, 4, 10], 100, 1),  # All below threshold
        ([1, 20, 4, 10], 5, 0),   # 20 > 5, so False
        ([1, 20, 4, 10], 21, 1),  # All below 21
        ([1, 20, 4, 10], 22, 1),  # All below 22
        ([1, 8, 4, 10], 11, 1),   # All below 11
        ([1, 8, 4, 10], 10, 0),   # 10 is NOT below 10 (equal)
        ([0, 0, 0, 0], 0, 0),     # All equal to threshold
        ([255, 255, 255, 255], 255, 0),  # Max values, all equal
        ([254, 254, 254, 254], 255, 1),  # Max values, all below
        ([1, 2, 3, 4, 5, 6, 7, 8], 9, 1),  # Full array, all below
        ([1, 2, 3, 4, 5, 6, 7, 8], 8, 0),  # Full array, one equal
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (numbers_list, threshold, expected) in enumerate(test_cases):
        # Extend or truncate to 8 elements
        padded_numbers = numbers_list + [0] * (8 - len(numbers_list))
        
        # Assign threshold
        dut.threshold.value = threshold
        
        # Assign array elements - handle 8 elements
        for j in range(8):
            dut.numbers[j].value = padded_numbers[j]
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Check output validity
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: Result is undefined (X/Z)")
        
        actual = int(dut.result.value)
        
        if actual == expected:
            dut._log.info(f"Test {i}: PASSED - nums={padded_numbers[:len(numbers_list)]}, thresh={threshold}, result={actual}")
            passed += 1
        else:
            raise TestFailure(f"Test {i}: FAILED - nums={padded_numbers[:len(numbers_list)]}, thresh={threshold}, expected={expected}, got={actual}")
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
