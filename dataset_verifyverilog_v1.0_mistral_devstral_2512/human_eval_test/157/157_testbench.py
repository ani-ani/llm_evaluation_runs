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
async def test_right_angle_triangle(dut):
    """Test the right_angle_triangle module with various triangle cases."""
    
    # Test cases: (a, b, c, expected_result)
    test_cases = [
        (3, 4, 5, True),
        (1, 2, 3, False),
        (10, 6, 8, True),
        (2, 2, 2, False),
        (7, 24, 25, True),
        (10, 5, 7, False),
        (5, 12, 13, True),
        (15, 8, 17, True),
        (48, 55, 73, True),
        (1, 1, 1, False),
        (2, 2, 10, False),
        (0, 0, 0, False),
        (1, 0, 1, False),
        (255, 255, 255, False),
        (20, 21, 29, True),
        (12, 16, 20, True),
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Starting test with {total} test cases")
    
    for i, (a, b, c, expected) in enumerate(test_cases):
        # Set inputs
        dut.side_a.value = a
        dut.side_b.value = b
        dut.side_c.value = c
        
        # Wait for combinational logic to propagate
        await Timer(10, units='ns')
        
        # Check if output is defined
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: Output is undefined (X/Z)")
        
        # Read result
        result = int(dut.result.value)
        expected_int = 1 if expected else 0
        
        if result == expected_int:
            dut._log.info(f"Test {i}: PASSED - ({a}, {b}, {c}) -> {result}")
            passed += 1
        else:
            raise TestFailure(f"Test {i}: FAILED - ({a}, {b}, {c}) expected {expected_int}, got {result}")
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
