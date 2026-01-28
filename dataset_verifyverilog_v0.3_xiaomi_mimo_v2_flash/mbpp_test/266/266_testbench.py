import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
SIDE_WIDTH = 8
RESULT_WIDTH = 16

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_lateral_surface_cube(dut):
    """Test lateral surface area calculation."""
    
    # Test cases: (side_length, expected_area, description)
    test_cases = [
        (5, 100, "side=5, 4*5*5=100"),
        (9, 324, "side=9, 4*9*9=324"),
        (10, 400, "side=10, 4*10*10=400"),
        (0, 0, "side=0, edge case"),
        (1, 4, "side=1, 4*1*1=4"),
        (255, 260100, "side=255, max value"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (side, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Clamp input to width
            side_clamped = clamp_to_width(side, SIDE_WIDTH)
            
            # Set input
            dut.side_length.value = side_clamped
            
            # Wait for combinational propagation
            await Timer(10, units='ns')
            
            # Read result
            if not is_value_defined(dut.area.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.area.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: area = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")