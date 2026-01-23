import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def factorial_last_digit_golden(n):
    """Golden model for factorial last digit"""
    if n == 0:
        return 1
    elif n == 1:
        return 1
    elif n == 2:
        return 2
    elif n == 3:
        return 6
    elif n == 4:
        return 4
    else:
        return 0

@cocotb.test()
async def test_factorial_last_digit(dut):
    """Test factorial last digit calculation"""
    
    # Test cases: (n, expected_last_digit)
    test_cases = [
        (0, 1),
        (1, 1),
        (2, 2),
        (3, 6),
        (4, 4),
        (5, 0),
        (6, 0),
        (7, 0),
        (10, 0),
        (21, 0),
        (30, 0),
        (100, 0),
        (255, 0)
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases for factorial_last_digit module")
    
    for n, expected in test_cases:
        # Set input
        dut.n.value = n
        
        # Wait for combinational logic to settle (small delay)
        await Timer(10, units='ns')
        
        # Read output
        actual = int(dut.last_digit.value)
        
        if actual == expected:
            dut._log.info(f"✓ n={n}: last_digit={actual} (expected {expected})")
            passed += 1
        else:
            dut._log.error(f"✗ n={n}: last_digit={actual} (expected {expected})")
            raise TestFailure(f"Test failed for n={n}: got {actual}, expected {expected}")
    
    dut._log.info(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
}