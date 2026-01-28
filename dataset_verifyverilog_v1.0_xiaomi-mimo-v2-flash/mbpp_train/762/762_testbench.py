import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helpers included for safety
def is_value_defined(v):
    try:
        int(v); return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_check_month_30_days(dut):
    """Test combinational 30-day month checker."""
    
    # Combinational module doesn't need clock/reset, but we wait for stability
    await Timer(10, units='ns')
    
    # Define test cases: (month_in, expected_is_30_days)
    # 4, 6, 9, 11 should return True (1)
    # Others should return False (0)
    test_cases = [
        (1, 0),  # Jan
        (2, 0),  # Feb
        (3, 0),  # Mar
        (4, 1),  # Apr (30 days)
        (5, 0),  # May
        (6, 1),  # Jun (30 days)
        (7, 0),  # Jul
        (8, 0),  # Aug
        (9, 1),  # Sep (30 days)
        (10, 0), # Oct
        (11, 1), # Nov (30 days)
        (12, 0), # Dec
        (0, 0),  # Invalid
        (13, 0), # Invalid
        (15, 0)  # Invalid
    ]
    
    failed = 0
    passed = 0
    
    for month, expected in test_cases:
        # Check if input signal exists
        if not hasattr(dut, 'month_in'):
            raise TestFailure("Input signal 'month_in' not found")
        
        # Assign input (4-bit width)
        dut.month_in.value = month
        
        # Allow propagation (though combinational, small delay is safe)
        await Timer(1, units='ns')
        
        # Read output
        if not hasattr(dut, 'is_30_days'):
            raise TestFailure("Output signal 'is_30_days' not found")
            
        if not is_value_defined(dut.is_30_days.value):
            raise TestFailure(f"Output undefined for month {month}")
            
        result = int(dut.is_30_days.value)
        
        if result != expected:
            cocotb.log.error(f"FAIL: Month {month}. Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"PASS: Month {month} -> {result}")
            passed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")