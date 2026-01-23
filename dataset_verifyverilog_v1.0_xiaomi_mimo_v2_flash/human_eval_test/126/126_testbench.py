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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_is_sorted(dut):
    """Test the is_sorted module with various cases."""
    
    # Helper to set array values
    def set_array(values):
        # Pad with zeros if length < 8
        padded = values + [0] * (8 - len(values))
        for i, val in enumerate(padded):
            dut.arr[i].value = val
    
    # Helper to check result
    async def check_result(expected):
        # Wait for combinational propagation
        await Timer(50, units='ns')
        
        if not is_value_defined(dut.result.value):
            raise TestFailure("Output has X/Z values")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        
        dut._log.info(f"Test passed: result={result}, expected={expected}")
    
    # Test cases adapted from Python
    test_cases = [
        ([5], True),                      # Single element
        ([1, 2, 3, 4, 5], True),         # Strictly increasing
        ([1, 3, 2, 4, 5], False),        # Unsorted
        ([1, 2, 3, 4, 5, 6], True),      # Increasing
        ([1, 2, 3, 4, 5, 6, 7], True),   # Increasing
        ([1, 3, 2, 4, 5, 6, 7], False),  # Unsorted
        ([], True),                      # Empty (all zeros -> sorted)
        ([1], True),                     # Single element
        ([3, 2, 1], False),              # Decreasing
        ([1, 2, 2, 2, 3, 4], False),     # Triple duplicate
        ([1, 2, 3, 3, 3, 4], False),     # Triple duplicate
        ([1, 2, 2, 3, 3, 4], True),      # Single duplicates allowed
        ([1, 2, 3, 4], True),            # Increasing
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (values, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}/{total}: Input={values}, Expected={expected}")
        
        # Set inputs
        set_array(values)
        
        # Check result
        try:
            await check_result(expected)
            passed += 1
        except TestFailure as e:
            dut._log.error(f"Test {i+1} failed: {e}")
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
