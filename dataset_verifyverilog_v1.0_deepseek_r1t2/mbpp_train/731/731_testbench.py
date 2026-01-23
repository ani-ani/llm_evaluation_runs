import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
Q_FORMAT_BITS = 16  # Fractional bits for Q16.16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

def float_to_q16_16(f):
    """Convert float to Q16.16 fixed-point integer."""
    return int(f * (1 << Q_FORMAT_BITS))

def q16_16_to_float(fixed):
    """Convert Q16.16 fixed-point integer to float."""
    return fixed / (1 << Q_FORMAT_BITS)

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
    return min(max_val, max(0, value))

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_cone_lsa(dut):
    """Test the cone lateral surface area module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (radius_float, height_float, expected_lsa_float)
    # From original test cases
    test_cases = [
        (5.0, 12.0, 204.20352248333654),
        (10.0, 15.0, 566.3586699569488),
        (19.0, 17.0, 1521.8090132193388),
    ]
    
    passed = 0
    failed = 0
    
    for i, (r_float, h_float, expected_lsa_float) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: r={r_float}, h={h_float}")
        cocotb.log.info(f"  Expected LSA (float): {expected_lsa_float}")
        
        try:
            # Convert to Q16.16
            r_fixed = float_to_q16_16(r_float)
            h_fixed = float_to_q16_16(h_float)
            expected_lsa_fixed = float_to_q16_16(expected_lsa_float)
            
            cocotb.log.info(f"  Input r (Q16.16): {r_fixed}")
            cocotb.log.info(f"  Input h (Q16.16): {h_fixed}")
            cocotb.log.info(f"  Expected LSA (Q16.16): {expected_lsa_fixed}")
            
            # Write inputs
            dut.radius.value = r_fixed
            dut.height.value = h_fixed
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.lsa.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_fixed = int(dut.lsa.value)
            result_float = q16_16_to_float(result_fixed)
            
            cocotb.log.info(f"  Result (Q16.16): {result_fixed}")
            cocotb.log.info(f"  Result (float): {result_float}")
            
            # Calculate error (allow ~0.01 tolerance due to fixed-point precision)
            absolute_error = abs(result_float - expected_lsa_float)
            relative_error = absolute_error / max(1.0, expected_lsa_float)
            
            cocotb.log.info(f"  Absolute error: {absolute_error:.6f}")
            cocotb.log.info(f"  Relative error: {relative_error * 100:.2f}%")
            
            # Check if within tolerance
            if absolute_error > 0.5:  # Tolerance of 0.5 (0.0077 in Q16.16)
                raise TestFailure(
                    f"Error too large: got {result_float:.6f}, "
                    f"expected {expected_lsa_float:.6f} (diff={absolute_error:.6f})"
                )
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")