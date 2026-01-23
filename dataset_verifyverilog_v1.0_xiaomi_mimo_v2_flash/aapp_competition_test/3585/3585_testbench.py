import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS - COPY THESE EXACTLY
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
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_fake_bag_counter(dut):
    """Test the fake bag counter module with sample inputs."""
    
    # Module is combinational, no clock or reset needed
    
    # Define test cases: (m, k, expected_result)
    test_cases = [
        (2, 1, 9),
        (2, 2, 17),
        # Add more cases as needed
    ]
    
    passed = 0
    failed = 0
    
    for m, k, expected in test_cases:
        # Set inputs
        dut.m.value = m
        dut.k.value = k
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Result is undefined (X/Z) for m={m}, k={k}")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        if result != expected:
            dut._log.error(f"Test failed for m={m}, k={k}: expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"Test passed for m={m}, k={k}: result={result}")
            passed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")