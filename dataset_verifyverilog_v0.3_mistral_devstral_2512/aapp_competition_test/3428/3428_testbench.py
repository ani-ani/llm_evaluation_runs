import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 8

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {port_name}")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_module(dut):
    """Main test function for distinct_gcd_count module."""
    
    # Since it's combinational, no clock needed
    
    # Define test cases: (inputs, expected_output, description)
    test_cases = [
        ([9, 6, 2, 4], 6, "Sample 1: 9,6,2,4 -> 6 distinct GCDs"),
        ([9, 6, 3, 4], 5, "Sample 2: 9,6,3,4 -> 5 distinct GCDs"),
        ([1, 1, 1, 1], 1, "All ones -> only GCD=1"),
        ([255, 255, 255, 255], 1, "All 255 -> only GCD=255"),
        ([2, 3, 5, 7], 4, "Primes -> each subarray has unique GCD (2,3,5,7)"),
        ([12, 18, 24, 30], 5, "Multiples of 6 -> GCDs 6,12,18,24,30?"),
        ([8, 12, 16], 3, "Three elements -> 3 distinct GCDs"),
        ([1, 2, 4, 8], 4, "Powers of 2 -> 4 distinct GCDs"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inputs, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Ensure input length is within ARRAY_SIZE
            if len(inputs) > ARRAY_SIZE:
                inputs = inputs[:ARRAY_SIZE]
            
            # Write inputs using helper
            await write_array(dut, 'arr', inputs, DATA_WIDTH)
            
            # Write length
            if has_signal(dut, 'len'):
                dut.len.value = len(inputs)
            else:
                raise TestFailure("Signal 'len' not found in DUT")
            
            # Wait for combinational logic to settle
            await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = safe_int(dut.result.value)
            
            # Verify result
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
