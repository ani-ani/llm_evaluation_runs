import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
SIDE_WIDTH = 8
VOLUME_WIDTH = 24

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
async def test_cube_volume(dut):
    """Test cube volume calculation."""
    
    # Define test cases: (side_length, expected_volume, description)
    test_cases = [
        (3, 27, "Side length 3, volume 27"),
        (2, 8, "Side length 2, volume 8"),
        (5, 125, "Side length 5, volume 125"),
        (0, 0, "Side length 0, volume 0"),
        (1, 1, "Side length 1, volume 1"),
        (10, 1000, "Side length 10, volume 1000"),
        (20, 8000, "Side length 20, volume 8000"),
        (255, 16581375, "Side length 255, max volume"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (side, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Clamp input to width
            side_clamped = clamp_to_width(side, SIDE_WIDTH)
            
            # Write input
            dut.side_length.value = side_clamped
            
            # Wait for combinational propagation
            await Timer(10, units='ns')
            
            # Read output
            if not is_value_defined(dut.volume.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.volume.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: side_length={side}, volume={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")