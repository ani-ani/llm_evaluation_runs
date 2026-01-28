import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# CONFIGURATION
# ============================================================================

CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Day mapping
DAYS = {
    'monday': 0,
    'tuesday': 1,
    'wednesday': 2,
    'thursday': 3,
    'friday': 4,
    'saturday': 5,
    'sunday': 6
}

# Expected results for test cases
TEST_CASES = [
    ("monday", "tuesday", "NO"),
    ("sunday", "sunday", "YES"),
    ("saturday", "tuesday", "YES"),
    ("tuesday", "thursday", "YES"),
    ("friday", "wednesday", "NO"),
    ("sunday", "saturday", "NO"),
    ("monday", "monday", "YES"),
    ("monday", "wednesday", "YES"),
    ("monday", "thursday", "YES"),
    ("monday", "friday", "NO"),
    ("monday", "saturday", "NO"),
    ("monday", "sunday", "NO"),
    ("tuesday", "monday", "NO"),
    ("tuesday", "tuesday", "YES"),
    ("tuesday", "wednesday", "NO"),
    ("tuesday", "friday", "YES"),
    ("tuesday", "saturday", "NO"),
    ("tuesday", "sunday", "NO"),
    ("wednesday", "monday", "NO"),
    ("wednesday", "tuesday", "NO"),
    ("wednesday", "wednesday", "YES"),
    ("wednesday", "thursday", "NO"),
    ("wednesday", "friday", "YES"),
    ("wednesday", "saturday", "YES"),
    ("wednesday", "sunday", "NO"),
    ("thursday", "monday", "NO"),
    ("thursday", "tuesday", "NO"),
    ("thursday", "wednesday", "NO"),
    ("thursday", "thursday", "YES"),
    ("thursday", "friday", "NO"),
    ("thursday", "saturday", "YES"),
    ("thursday", "sunday", "YES"),
    ("friday", "monday", "YES"),
    ("friday", "tuesday", "NO"),
    ("friday", "thursday", "NO"),
    ("friday", "saturday", "NO"),
    ("friday", "sunday", "YES"),
    ("saturday", "monday", "YES"),
    ("saturday", "wednesday", "NO"),
    ("saturday", "thursday", "NO"),
    ("saturday", "friday", "NO"),
    ("saturday", "saturday", "YES"),
    ("saturday", "sunday", "NO"),
    ("sunday", "monday", "NO"),
    ("sunday", "tuesday", "YES"),
    ("sunday", "wednesday", "YES"),
    ("sunday", "thursday", "NO"),
    ("sunday", "friday", "NO"),
    ("friday", "friday", "YES"),
    ("friday", "sunday", "YES"),
    ("monday", "monday", "YES"),
    ("friday", "tuesday", "YES"),
    ("thursday", "saturday", "YES"),
    ("tuesday", "friday", "YES"),
    ("sunday", "wednesday", "YES"),
    ("monday", "thursday", "YES"),
    ("saturday", "sunday", "NO"),
    ("friday", "monday", "YES"),
    ("thursday", "thursday", "YES"),
    ("wednesday", "friday", "YES"),
    ("thursday", "monday", "NO"),
    ("wednesday", "sunday", "NO"),
    ("thursday", "friday", "NO"),
    ("monday", "friday", "NO"),
    ("wednesday", "saturday", "YES"),
    ("thursday", "sunday", "YES"),
    ("saturday", "friday", "NO"),
    ("saturday", "monday", "YES")
]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_day_checker(dut):
    """Test the day_checker module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.day1.value = 0
    dut.day2.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    failed = 0
    
    for i, (day1_str, day2_str, expected_str) in enumerate(TEST_CASES):
        cocotb.log.info(f"Test {i+1}: {day1_str} -> {day2_str}")
        
        try:
            # Convert day names to numbers
            day1_num = DAYS[day1_str]
            day2_num = DAYS[day2_str]
            
            # Set inputs
            dut.day1.value = day1_num
            dut.day2.value = day2_num
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            timeout = 0
            while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
                await RisingEdge(dut.clk)
                timeout += 1
                if timeout > 10:
                    raise TestFailure(f"Timeout waiting for done")
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined")
            
            result = int(dut.result.value)
            expected = 1 if expected_str == "YES" else 0
            
            if result != expected:
                raise TestFailure(f"Expected {expected_str}, got {'YES' if result else 'NO'}")
            
            cocotb.log.info(f"  PASS: Result = {expected_str}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")