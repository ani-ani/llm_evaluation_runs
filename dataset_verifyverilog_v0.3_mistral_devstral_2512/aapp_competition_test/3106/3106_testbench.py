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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_lights_time(dut):
    """Verify the lights_time module for the three given test cases."""
    
    # Detect interface
    has_len = has_signal(dut, 'len')
    has_s = has_signal(dut, 's')
    has_time = has_signal(dut, 'time')
    
    if not (has_len and has_s and has_time):
        raise TestFailure("Missing required signals: len, s, time")
    
    # Test cases: (len, s_value, expected_time, description)
    # s_value is the 16‑bit vector where bit i corresponds to light i+1
    test_cases = [
        (4, 0b0000000000000000_0000000000001011, 1, "1101"),  # lights 1,2,4 on
        (1, 0b0000000000000000_0000000000000001, 0, "1"),     # single light on
        (3, 0b0000000000000000_0000000000000000, 2, "000"),   # three lights off
    ]
    
    passed = 0
    failed = 0
    
    for len_val, s_val, expected, desc in test_cases:
        dut._log.info(f"Testing: len={len_val}, s={s_val:016b} (string '{desc}')")
        
        # Assign inputs
        dut.len.value = len_val
        dut.s.value = s_val
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Read output
        if not is_value_defined(dut.time.value):
            dut._log.error("Output 'time' is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.time.value)
        
        if result == expected:
            dut._log.info(f"  PASS: time = {result}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
    
    # Summary
    dut._log.info("="*50)
    dut._log.info(f"Results: {passed}/{len(test_cases)} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
