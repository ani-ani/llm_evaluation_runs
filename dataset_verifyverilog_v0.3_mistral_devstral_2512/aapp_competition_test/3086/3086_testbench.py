import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 10
CLK_PERIOD_NS = 10

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

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_event_duration(dut):
    """Test the event_duration module with multiple test cases."""
    
    # Define test cases: (start_month, start_day, end_month, end_day, F1, expected_result, expected_valid, description)
    test_cases = [
        (2, 26, 3, 3, 1, 5, 1, "Example 1: non-crossing, single event"),
        (2, 26, 3, 3, 2, 185, 1, "Example 2: crossing, two events"),
        (12, 31, 1, 1, 1, 1, 1, "Year boundary crossing"),
        (1, 1, 12, 31, 1, 364, 1, "Full year non-crossing"),
        (1, 1, 1, 1, 0, 1, 1, "Zero count, same day"),
        (1, 1, 1, 1, 1, 365, 1, "Same day, crossing solution"),
        (2, 26, 3, 3, 3, -1, 0, "No solution: remainder"),
        (2, 26, 3, 3, 5, 1, 1, "Solution from L_same"),
        (2, 26, 3, 3, 10, 37, 1, "Solution from L_cross"),
        (2, 26, 3, 3, 200, -1, 0, "No solution: quotient out of range"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (sm, sd, em, ed, f1, exp_res, exp_valid, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Assign inputs
        dut.start_month.value = sm
        dut.start_day.value = sd
        dut.end_month.value = em
        dut.end_day.value = ed
        dut.F1.value = f1
        
        # Wait for combinational propagation
        await Timer(50, units='ns')
        
        # Read outputs
        if not is_value_defined(dut.valid.value):
            cocotb.log.error(f"  FAIL: valid is undefined (X/Z)")
            failed += 1
            continue
            
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"  FAIL: result is undefined (X/Z)")
            failed += 1
            continue
        
        actual_valid = int(dut.valid.value)
        actual_result_raw = int(dut.result.value)
        actual_result = to_signed(actual_result_raw, RESULT_WIDTH)
        
        # Validate
        if actual_valid != exp_valid:
            cocotb.log.error(f"  FAIL: valid={actual_valid}, expected {exp_valid}")
            failed += 1
            continue
            
        if exp_valid == 1:
            if actual_result != exp_res:
                cocotb.log.error(f"  FAIL: result={actual_result}, expected {exp_res}")
                failed += 1
                continue
        else:
            # When invalid, result should be -1
            if actual_result != -1:
                cocotb.log.error(f"  FAIL: invalid result should be -1, got {actual_result}")
                failed += 1
                continue
        
        cocotb.log.info(f"  PASS: result={actual_result}, valid={actual_valid}")
        passed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")