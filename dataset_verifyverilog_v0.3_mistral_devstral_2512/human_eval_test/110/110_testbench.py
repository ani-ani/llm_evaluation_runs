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

async def wait_for_valid_output(dut, timeout_ns=1000):
    """Wait for combinational output to become valid."""
    elapsed = 0
    while elapsed < timeout_ns:
        await Timer(10, units='ns')
        elapsed += 10
        if is_value_defined(dut.result.value):
            return int(dut.result.value)
    raise TestFailure(f"Timeout: output not valid after {timeout_ns}ns")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_exchange_check(dut):
    """Test the exchange_check module."""
    
    # Helper to set array values
    def set_array(handle, values):
        for i, val in enumerate(values):
            handle[i].value = val
    
    # Helper to compute expected result
    def compute_expected(lst1, lst2):
        odd1 = sum(1 for x in lst1 if x % 2 == 1)
        even2 = sum(1 for x in lst2 if x % 2 == 0)
        return 1 if odd1 <= even2 else 0
    
    # Test cases: (lst1, lst2, expected_result, description)
    test_cases = [
        ([1, 2, 3, 4, 0, 0, 0, 0], [1, 2, 3, 4, 0, 0, 0, 0], 1, "Original case: [1,2,3,4] vs [1,2,3,4]"),
        ([1, 2, 3, 4, 0, 0, 0, 0], [1, 5, 3, 4, 0, 0, 0, 0], 0, "Original case: [1,2,3,4] vs [1,5,3,4]"),
        ([1, 2, 3, 4, 0, 0, 0, 0], [2, 1, 4, 3, 0, 0, 0, 0], 1, "Original case: [1,2,3,4] vs [2,1,4,3]"),
        ([5, 7, 3, 0, 0, 0, 0, 0], [2, 6, 4, 0, 0, 0, 0, 0], 1, "Original case: [5,7,3] vs [2,6,4]"),
        ([5, 7, 3, 0, 0, 0, 0, 0], [2, 6, 3, 0, 0, 0, 0, 0], 0, "Original case: [5,7,3] vs [2,6,3]"),
        ([3, 2, 6, 1, 8, 9, 0, 0], [3, 5, 5, 1, 1, 1, 0, 0], 0, "Original case: [3,2,6,1,8,9] vs [3,5,5,1,1,1]"),
        ([100, 200, 0, 0, 0, 0, 0, 0], [200, 200, 0, 0, 0, 0, 0, 0], 1, "Edge case: all even"),
        ([1, 3, 5, 7, 9, 11, 13, 15], [2, 4, 6, 8, 10, 12, 14, 16], 1, "All odd in lst1, all even in lst2"),
        ([1, 3, 5, 7, 9, 11, 13, 15], [1, 2, 3, 4, 5, 6, 7, 8], 0, "All odd in lst1, not enough evens in lst2"),
        ([2, 4, 6, 8, 0, 0, 0, 0], [1, 3, 5, 7, 0, 0, 0, 0], 1, "All even in lst1, always YES"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (lst1, lst2, expected, description) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {description}")
        
        # Set input arrays
        set_array(dut.lst1, lst1)
        set_array(dut.lst2, lst2)
        
        # Wait for combinational logic to propagate
        await Timer(50, units='ns')
        
        # Get result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        # Verify
        if result != expected:
            raise TestFailure(f"Test {i+1}: expected {expected}, got {result} - {description}")
        
        dut._log.info(f"  Result: {result} (expected {expected}) [OK]")
        passed += 1
    
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")