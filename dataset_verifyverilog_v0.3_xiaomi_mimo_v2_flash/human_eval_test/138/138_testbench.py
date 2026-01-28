import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper function to check if value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test()
async def test_sum_even_check(dut):
    """Test the sum_even_check module with all test cases"""
    
    # Test cases: (input_n, expected_result)
    test_cases = [
        (4, 0),   # 4: even but < 8
        (6, 0),   # 6: even but < 8
        (8, 1),   # 8: valid (2+2+2+2)
        (10, 0),  # 10: even but cannot be 4 positive evens (would need 2+2+2+4=10, but that's 3 numbers)
        (11, 0),  # 11: odd
        (12, 1),  # 12: valid (2+2+2+6)
        (13, 0),  # 13: odd
        (16, 1),  # 16: valid (2+2+6+6)
    ]
    
    dut._log.info("Running sum_even_check tests...")
    passed = 0
    total = len(test_cases)
    
    for i, (input_n, expected) in enumerate(test_cases):
        # Set input
        dut.n.value = input_n
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Check if output is defined
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: Output is undefined (X/Z) for n={input_n}")
        
        # Read result
        result = int(dut.result.value)
        
        # Verify
        if result != expected:
            raise TestFailure(f"Test {i}: n={input_n}, expected {expected}, got {result}")
        
        dut._log.info(f"Test {i}: n={input_n}, result={result} [PASS]")
        passed += 1
    
    # Summary
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    if passed == total:
        dut._log.info("All tests passed!")
    else:
        raise TestFailure(f"Only {passed}/{total} tests passed")