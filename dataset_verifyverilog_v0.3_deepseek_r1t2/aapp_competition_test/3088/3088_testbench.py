import cocotb
from cocotb.triggers import Timer
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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_largest_number_after_k_swaps(dut):
    """Test the largest_number_after_k_swaps module."""
    
    # Define test cases: (n, k, expected_result)
    test_cases = [
        (1374, 2, 7413),
        (210, 1, 201),
        (666, 3, 666),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, k, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, k={k}, expected={expected}")
        
        # Set inputs
        dut.n.value = n
        dut.k.value = k
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")