import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 3

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
async def test_three_equal_counter(dut):
    """Test the three_equal_counter module with all test cases."""
    
    # Define test cases: (x, y, z, expected_result, description)
    # Note: Test cases use signed integers, need to convert to unsigned for Verilog
    test_cases = [
        (1, 1, 1, 3, "All three equal (1,1,1)"),
        (-1, -2, -3, 0, "All different negative (-1,-2,-3)"),
        (1, 2, 2, 2, "Two equal (1,2,2)"),
        # Additional edge cases
        (0, 0, 0, 3, "All zeros"),
        (127, 127, 127, 3, "All max positive (127)"),
        (-128, -128, -128, 3, "All min negative (-128)"),
        (100, 100, 50, 2, "Two equal (100,100,50)"),
        (50, 100, 100, 2, "Two equal (50,100,100)"),
        (100, 50, 100, 2, "Two equal (100,50,100)"),
        (10, 20, 30, 0, "All different positive"),
        (-10, 20, 30, 0, "Mixed signs all different"),
        (-5, -5, 5, 2, "Two negatives equal"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (x_val, y_val, z_val, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: x={x_val}, y={y_val}, z={z_val}")
        
        try:
            # Convert signed integers to unsigned for Verilog assignment
            x_unsigned = from_signed(x_val, DATA_WIDTH)
            y_unsigned = from_signed(y_val, DATA_WIDTH)
            z_unsigned = from_signed(z_val, DATA_WIDTH)
            
            # Assign values to DUT
            dut.x.value = x_unsigned
            dut.y.value = y_unsigned
            dut.z.value = z_unsigned
            
            # Wait for combinational logic to settle
            await Timer(10, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
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
