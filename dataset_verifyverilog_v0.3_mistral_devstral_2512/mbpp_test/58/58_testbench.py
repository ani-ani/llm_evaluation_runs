import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_opposite_signs(dut):
    """Test the opposite_signs module with all test cases."""
    
    # Define test cases: (x, y, expected_result, description)
    test_cases = [
        (1, -2, True, "Test 1: 1 and -2 have opposite signs"),
        (3, 2, False, "Test 2: 3 and 2 have same sign (positive)"),
        (-10, -10, False, "Test 3: -10 and -10 have same sign (negative)"),
        (-2, 2, True, "Test 4: -2 and 2 have opposite signs"),
        
        # Additional edge cases
        (0, 1, False, "Edge: 0 (positive) and 1"),
        (0, -1, True, "Edge: 0 (positive) and -1"),
        (-128, 127, True, "Edge: min and max values"),
        (127, 127, False, "Edge: both max positive"),
        (-128, -128, False, "Edge: both min negative"),
        (127, -128, True, "Edge: max positive and min negative"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (x_val, y_val, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Convert signed values to unsigned for Verilog assignment
            x_unsigned = from_signed(x_val, DATA_WIDTH)
            y_unsigned = from_signed(y_val, DATA_WIDTH)
            
            # Assign inputs
            dut.x.value = x_unsigned
            dut.y.value = y_unsigned
            
            # Wait for combinational logic to settle
            await Timer(10, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            expected_int = 1 if expected else 0
            
            # Verify
            if result != expected_int:
                raise TestFailure(f"Expected {expected_int}, got {result}")
            
            # Convert back to signed for logging
            x_signed = to_signed(x_unsigned, DATA_WIDTH)
            y_signed = to_signed(y_unsigned, DATA_WIDTH)
            
            cocotb.log.info(f"  PASS: x={x_signed}, y={y_signed}, result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")