import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 32
TOLERANCE = 0.0001  # Allow for fixed-point rounding

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

def q16_to_float(q16_value):
    """Convert Q16.16 fixed-point to float."""
    return q16_value / 65536.0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_memory_game_expected(dut):
    """Test memory game expected turns calculation."""
    
    # Test cases: (N, expected_float)
    # Values computed using formula E(n) = n + (2/3) * H_{n-1}
    test_cases = [
        (1, 1.000000000000),
        (2, 2.666666666667),
        (3, 4.000000000000),
        (4, 5.222222222222),
        (5, 6.388888888889),
        (6, 7.522222222222),
        (7, 8.633333333333),
        (8, 9.728571428571),
    ]
    
    passed = 0
    failed = 0
    
    for n, expected in test_cases:
        cocotb.log.info(f"Testing N={n}")
        
        try:
            # Write N to DUT
            dut.n.value = n
            
            # Wait for combinational logic to settle
            await Timer(50, units='ns')
            
            # Read result
            if not is_value_defined(dut.expected.value):
                raise TestFailure(f"Output undefined for N={n}")
            
            result_q16 = int(dut.expected.value)
            result_float = q16_to_float(result_q16)
            
            # Check within tolerance
            diff = abs(result_float - expected)
            if diff > TOLERANCE:
                raise TestFailure(
                    f"Expected {expected:.12f}, got {result_float:.12f} "
                    f"(diff={diff:.6f}, Q16=0x{result_q16:08X})"
                )
            
            cocotb.log.info(f"  PASS: {result_float:.12f} (Q16=0x{result_q16:08X})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")