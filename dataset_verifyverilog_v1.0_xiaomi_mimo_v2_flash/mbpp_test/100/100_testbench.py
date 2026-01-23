import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_next_smallest_palindrome(dut):
    """Test next_smallest_palindrome module."""
    
    # Test cases: (input, expected_output, description)
    test_cases = [
        (99, 101, "99 -> 101"),
        (1221, 1331, "1221 -> 1331"),
        (120, 121, "120 -> 121"),
        (9, 11, "9 -> 11"),
        (11, 22, "11 -> 22"),
        (88, 99, "88 -> 99"),
        (123, 131, "123 -> 131"),
        (1, 2, "1 -> 2"),
        (0, 1, "0 -> 1"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (num_in, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Set input
            dut.num.value = num_in
            
            # Wait for combinational logic to settle
            await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            if not is_value_defined(dut.valid.value):
                raise TestFailure(f"Valid flag is undefined (X/Z)")
            
            result = int(dut.result.value)
            valid = int(dut.valid.value)
            
            if not valid:
                raise TestFailure(f"Valid flag not asserted")
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")