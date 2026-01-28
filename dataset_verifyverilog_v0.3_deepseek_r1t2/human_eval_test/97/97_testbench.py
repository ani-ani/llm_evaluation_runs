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

def get_unit_digit(n):
    """Get unit digit of integer n (ignoring sign)."""
    return abs(n) % 10

def expected_result(a, b):
    """Calculate expected result."""
    return get_unit_digit(a) * get_unit_digit(b)

@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_unit_digit_multiply(dut):
    """Test unit digit multiplication."""
    
    # Test cases from the problem
    test_cases = [
        (148, 412, 16),
        (19, 28, 72),
        (2020, 1851, 0),
        (14, -15, 20),
        (76, 67, 42),
        (17, 27, 49),
        (0, 1, 0),
        (0, 0, 0),
        # Additional edge cases
        (-1, -9, 9),      # Both negative
        (9999, 9999, 1),  # Large numbers, unit digit 9*9=81
        (123, -456, 18),  # Mixed sign, 3*6=18
        (5, 5, 25),       # Single digit
    ]
    
    dut._log.info("Testing unit digit multiplication...")
    passed = 0
    total = len(test_cases)
    
    for i, (a, b, expected) in enumerate(test_cases):
        # Set inputs
        dut.a.value = a
        dut.b.value = b
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Check output is defined
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: Output is undefined (X/Z)")
        
        # Read result
        result = int(dut.result.value)
        
        # Verify
        if result == expected:
            dut._log.info(f"Test {i}: PASSED - a={a}, b={b}, result={result}")
            passed += 1
        else:
            raise TestFailure(f"Test {i}: FAILED - a={a}, b={b}, expected {expected}, got {result}")
    
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    
    if passed == total:
        dut._log.info("All tests completed successfully!")
    else:
        raise TestFailure(f"Only {passed}/{total} tests passed")
