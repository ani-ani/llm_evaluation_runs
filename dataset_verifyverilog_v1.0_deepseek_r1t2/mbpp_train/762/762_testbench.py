import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4
CLK_PERIOD_NS = 10

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
async def test_month_has_30_days(dut):
    """Test the month_has_30_days module."""
    
    # Test cases: (month_num, expected_has_30_days, description)
    test_cases = [
        (1, False, "January has 31 days"),
        (2, False, "February has 28/29 days"),
        (3, False, "March has 31 days"),
        (4, True, "April has 30 days"),
        (5, False, "May has 31 days"),
        (6, True, "June has 30 days"),
        (7, False, "July has 31 days"),
        (8, False, "August has 31 days"),
        (9, True, "September has 30 days"),
        (10, False, "October has 31 days"),
        (11, True, "November has 30 days"),
        (12, False, "December has 31 days"),
        (0, False, "Invalid month 0"),
        (13, False, "Invalid month 13"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (month_num, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Set input
            dut.month_num.value = month_num
            
            # Wait for combinational logic to settle
            await Timer(10, units='ns')
            
            # Read output
            if not is_value_defined(dut.has_30_days.value):
                raise TestFailure(f"Output is undefined (X/Z)")
            
            result = int(dut.has_30_days.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Month {month_num}: expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: month_num={month_num}, has_30_days={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")