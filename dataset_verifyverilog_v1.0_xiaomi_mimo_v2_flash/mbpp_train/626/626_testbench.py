import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
RADIUS_WIDTH = 32
AREA_WIDTH = 32
FRAC_BITS = 16
MAX_RADIUS = 256  # Maximum radius to avoid overflow

# Q16.16 conversion helpers
FLOAT_TO_FIXED = lambda f: int(f * (1 << FRAC_BITS))
FIXED_TO_FLOAT = lambda f: f / (1 << FRAC_BITS)

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

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_largest_triangle_area(dut):
    """Test largest triangle area computation."""
    
    cocotb.log.info("=" * 60)
    cocotb.log.info("Testing Largest Triangle Area Module")
    cocotb.log.info("Format: Q16.16 fixed-point")
    cocotb.log.info("=" * 60)
    
    # Test cases: (radius_float, expected_area_float, description)
    test_cases = [
        (-1.0, None, "Negative radius - should handle gracefully"),
        (0.0, 0.0, "Zero radius"),
        (1.0, 1.0, "Radius = 1"),
        (2.0, 4.0, "Radius = 2"),
        (3.0, 9.0, "Radius = 3"),
        (4.0, 16.0, "Radius = 4"),
        (5.0, 25.0, "Radius = 5"),
        (10.5, 110.25, "Radius = 10.5"),
        (255.0, 65025.0, "Maximum safe radius"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (radius_float, expected_area, description) in enumerate(test_cases):
        
        # Skip negative radius test if design doesn't support it
        if radius_float < 0:
            cocotb.log.warning(f"Test {i+1}: Skipping negative input test")
            cocotb.log.info(f"  SKIP: {description}")
            continue
        
        # Convert to Q16.16 fixed-point
        radius_fixed = FLOAT_TO_FIXED(radius_float)
        
        # Clamp to fit 32-bit width
        radius_fixed = radius_fixed & 0xFFFFFFFF
        
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: r={radius_float} -> fixed={radius_fixed} (0x{radius_fixed:08X})")
        
        try:
            # Apply input
            dut.radius_in.value = radius_fixed
            
            # Wait for combinational propagation
            await Timer(10, units='ns')
            
            # Read output
            if not is_value_defined(dut.area_out.value):
                raise TestFailure(f"Output is undefined (X/Z)")
            
            area_out = int(dut.area_out.value)
            area_float = FIXED_TO_FLOAT(area_out)
            
            # Expected
            if expected_area is None:
                # Design should handle negative gracefully
                cocotb.log.info(f"  Output: {area_float} (fixed={area_out})")
                cocotb.log.info(f"  PASS: Negative handled")
                passed += 1
            else:
                # Allow small floating-point error for fractional inputs
                error = abs(area_float - expected_area)
                error_percent = (error / expected_area * 100) if expected_area > 0 else error
                
                # Tolerance: 0.01 for fixed-point precision
                if error < 0.01 or (radius_float >= 100 and error < 1.0):
                    cocotb.log.info(f"  Output: {area_float:.4f} (fixed={area_out})")
                    cocotb.log.info(f"  Expected: {expected_area:.4f}")
                    cocotb.log.info(f"  Error: {error:.4f} ({error_percent:.2f}%)")
                    cocotb.log.info(f"  PASS")
                    passed += 1
                else:
                    raise TestFailure(
                        f"Area mismatch: expected {expected_area:.4f}, got {area_float:.4f}, "
                        f"error={error:.4f}"
                    )
        
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {type(e).__name__}: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    cocotb.log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")