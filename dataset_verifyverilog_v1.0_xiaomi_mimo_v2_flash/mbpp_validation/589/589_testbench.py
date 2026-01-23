import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
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
async def test_perfect_squares(dut):
    """Test perfect squares ROM module."""
    
    # Define test cases: (lower_bound, upper_bound, expected_squares_list)
    # Note: We scale down inputs to fit 8-bit range (0-255)
    test_cases = [
        (1, 30, [1, 4, 9, 16, 25]),
        (50, 100, [64, 81, 100]),
        (100, 200, [100, 121, 144, 169, 196]),
        (0, 0, [0]),  # Edge case: 0 is a perfect square
        (200, 255, [225]),  # Only 225 in this range
        (150, 180, [169]),  # Only 169 in this range
        (226, 255, []),  # No perfect squares in range
    ]
    
    passed = 0
    failed = 0
    
    for i, (lower, upper, expected_squares) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Range [{lower}, {upper}]")
        
        try:
            # Set inputs
            dut.a.value = lower
            dut.b.value = upper
            
            # Wait for combinational logic to settle
            await Timer(10, units='ns')
            
            # Read result mask
            if not is_value_defined(dut.matches.value):
                raise TestFailure(f"Result mask is undefined (X/Z)")
            
            mask = int(dut.matches.value)
            
            # Extract squares from mask
            found_squares = []
            for sq in range(256):  # Check bits 0-255
                if mask & (1 << sq):
                    found_squares.append(sq)
            
            # Verify
            if sorted(found_squares) != sorted(expected_squares):
                raise TestFailure(f"Expected {expected_squares}, got {found_squares} (mask={mask:016x})")
            
            cocotb.log.info(f"  PASS: Found squares {found_squares}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")