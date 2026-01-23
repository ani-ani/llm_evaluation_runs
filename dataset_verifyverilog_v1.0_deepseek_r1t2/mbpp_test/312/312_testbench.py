import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000
RADIUS_WIDTH = 16
HEIGHT_WIDTH = 16
RESULT_WIDTH = 32

# Fixed-point constants for verification
FRAC_BITS = 16
PI_FIXED = 205887
ONE_THIRD = 21845

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

def float_to_fixed(f, frac_bits=FRAC_BITS):
    """Convert float to fixed-point integer."""
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=FRAC_BITS):
    """Convert fixed-point integer to float."""
    return fixed / (1 << frac_bits)

def compute_volume_fixed(radius, height):
    """Compute volume using fixed-point arithmetic (same as HDL)."""
    r_squared = radius * radius
    r_squared_h = r_squared * height
    temp = (r_squared_h * PI_FIXED) >> 16
    result = (temp * ONE_THIRD) >> 16
    return result

async def reset_dut(dut):
    """Reset the DUT."""
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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cone_volume(dut):
    """Test cone volume calculation with fixed-point arithmetic."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (radius, height, expected_tolerance)
    # Note: We compute expected values using Python fixed-point arithmetic
    test_cases = [
        (5, 12, 0.01),
        (10, 15, 0.01),
        (19, 17, 0.01),
    ]
    
    passed = 0
    failed = 0
    
    for i, (radius, height, tolerance) in enumerate(test_cases):
        
        # Compute expected value
        float_result = (1.0/3) * math.pi * radius * radius * height
        expected_fixed = compute_volume_fixed(radius, height)
        expected_float = fixed_to_float(expected_fixed)
        
        cocotb.log.info(f"Test {i+1}: r={radius}, h={height}")
        cocotb.log.info(f"  Expected float: {float_result:.6f}")
        cocotb.log.info(f"  Expected fixed-point Q16.16: {expected_fixed} ({expected_float:.6f})")
        
        try:
            # Clamp inputs to width
            radius_clamped = clamp_to_width(radius, RADIUS_WIDTH)
            height_clamped = clamp_to_width(height, HEIGHT_WIDTH)
            
            # Set inputs
            dut.radius.value = radius_clamped
            dut.height.value = height_clamped
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.volume.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result_fixed = int(dut.volume.value)
            result_float = fixed_to_float(result_fixed)
            
            cocotb.log.info(f"  Result fixed-point: {result_fixed} ({result_float:.6f})")
            
            # Compare with relative tolerance
            rel_error = abs(result_float - float_result) / float_result if float_result != 0 else abs(result_float - float_result)
            
            if rel_error > tolerance:
                raise TestFailure(f"Relative error {rel_error:.6f} exceeds tolerance {tolerance}")
            
            cocotb.log.info(f"  PASS (error: {rel_error:.6f})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")