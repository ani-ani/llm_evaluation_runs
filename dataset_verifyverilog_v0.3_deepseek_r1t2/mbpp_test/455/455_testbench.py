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

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_check_monthnumb_number(dut):
    """Test the check_monthnumb_number module."""
    
    # Test cases: (month, expected_result, description)
    test_cases = [
        (5, True, "Month 5 (May) has 31 days"),
        (2, False, "Month 2 (February) does not have 31 days"),
        (6, False, "Month 6 (June) does not have 31 days"),
        (1, True, "Month 1 (January) has 31 days"),
        (3, True, "Month 3 (March) has 31 days"),
        (7, True, "Month 7 (July) has 31 days"),
        (8, True, "Month 8 (August) has 31 days"),
        (10, True, "Month 10 (October) has 31 days"),
        (12, True, "Month 12 (December) has 31 days"),
        (4, False, "Month 4 (April) does not have 31 days"),
        (9, False, "Month 9 (September) does not have 31 days"),
        (11, False, "Month 11 (November) does not have 31 days"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (month, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        # Assign input
        dut.monthnum2.value = month
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Check if output is defined
        if not is_value_defined(dut.has_31_days.value):
            cocotb.log.error(f"  FAIL: Output is undefined (X/Z)")
            failed += 1
            continue
        
        # Read result
        result = int(dut.has_31_days.value)
        expected_int = 1 if expected else 0
        
        # Verify
        if result == expected_int:
            cocotb.log.info(f"  PASS: has_31_days = {result} (expected {expected_int})")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: Expected {expected_int}, got {result}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
