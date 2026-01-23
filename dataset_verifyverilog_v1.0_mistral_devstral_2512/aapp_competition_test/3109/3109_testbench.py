import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# FIXED-POINT CONVERSION HELPERS
# ============================================================================

def float_to_fixed(f, frac_bits=16):
    """Convert float to Q16.16 fixed-point."""
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=16):
    """Convert Q16.16 fixed-point to float."""
    return fixed / (1 << frac_bits)

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sand_art_balancer(dut):
    """Test the sand art balancer module."""
    
    # Configuration
    DATA_WIDTH = 32
    FRAC_BITS = 16
    CLK_PERIOD_NS = 10
    N = 4  # Max sections in HDL
    M = 4  # Max colors in HDL
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Simple balanced distribution
    dut._log.info("Test Case 1: Balanced distribution")
    
    # Scale down the problem for HDL
    # Original: n=2, m=2, volumes=[2.0, 2.0], widths=[4.0, 1.0]
    # Scaled: n=2, m=2, volumes=[1.0, 1.0], widths=[2.0, 1.0]
    
    volumes = [1.0, 1.0]  # Scaled volumes
    widths = [2.0, 1.0]   # Scaled widths
    
    # Min/Max constraints (scaled)
    min_vals = [
        [0.5, 0.0],  # Section 0: min 0.5 of color 0, 0.0 of color 1
        [0.0, 0.5]   # Section 1: min 0.0 of color 0, 0.5 of color 1
    ]
    max_vals = [
        [1.0, 0.5],  # Section 0: max 1.0 of color 0, 0.5 of color 1
        [0.5, 1.0]   # Section 1: max 0.5 of color 0, 1.0 of color 1
    ]
    
    num_sections = 2
    num_colors = 2
    
    # Convert to fixed-point and assign to DUT
    # Note: In real implementation, we would assign to individual array elements
    for i in range(num_sections):
        # Assign widths
        width_val = float_to_fixed(widths[i], FRAC_BITS)
        # Use getattr since array indexing might not work directly
        if has_signal(dut, f'widths_{i}'):
            getattr(dut, f'widths_{i}').value = clamp_to_width(width_val, DATA_WIDTH)
        elif has_signal(dut, 'widths'):
            # If it's a proper array
            dut.widths[i].value = clamp_to_width(width_val, DATA_WIDTH)
    
    for j in range(num_colors):
        # Assign volumes
        vol_val = float_to_fixed(volumes[j], FRAC_BITS)
        if has_signal(dut, f'volumes_{j}'):
            getattr(dut, f'volumes_{j}').value = clamp_to_width(vol_val, DATA_WIDTH)
        elif has_signal(dut, 'volumes'):
            dut.volumes[j].value = clamp_to_width(vol_val, DATA_WIDTH)
    
    # Assign min/max constraints
    for i in range(num_sections):
        for j in range(num_colors):
            min_val = float_to_fixed(min_vals[i][j], FRAC_BITS)
            max_val = float_to_fixed(max_vals[i][j], FRAC_BITS)
            
            # Try various naming conventions
            if has_signal(dut, f'min_vals_{i}_{j}'):
                getattr(dut, f'min_vals_{i}_{j}').value = clamp_to_width(min_val, DATA_WIDTH)
                getattr(dut, f'max_vals_{i}_{j}').value = clamp_to_width(max_val, DATA_WIDTH)
            elif has_signal(dut, f'min_vals_{i}'):
                # If it's a 2D array
                dut.min_vals[i][j].value = clamp_to_width(min_val, DATA_WIDTH)
                dut.max_vals[i][j].value = clamp_to_width(max_val, DATA_WIDTH)
    
    # Assign dimension parameters
    if has_signal(dut, 'num_sections'):
        dut.num_sections.value = num_sections
    if has_signal(dut, 'num_colors'):
        dut.num_colors.value = num_colors
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done signal
    max_cycles = 1000
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
        if cycle == max_cycles - 1:
            raise TestFailure("Timeout waiting for done signal")
    
    # Read result
    if has_signal(dut, 'min_difference') and is_value_defined(dut.min_difference.value):
        result_fixed = int(dut.min_difference.value)
        result_float = fixed_to_float(result_fixed, FRAC_BITS)
        
        # Expected difference (approximately 0.75 in original problem)
        # For scaled problem, expect approximately 0.25
        expected = 0.25
        
        # Allow some tolerance for fixed-point arithmetic
        tolerance = 0.05
        if abs(result_float - expected) > tolerance:
            raise TestFailure(f"Expected ~{expected}, got {result_float}")
        
        dut._log.info(f"Test passed: difference = {result_float:.3f}")
    else:
        raise TestFailure("Cannot read min_difference signal")
    
    # Test Case 2: Another configuration
    dut._log.info("Test Case 2: Different configuration")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # New test case
    volumes = [1.5, 1.5]
    widths = [2.0, 1.0]
    min_vals = [
        [0.75, 0.0],
        [0.0, 0.75]
    ]
    max_vals = [
        [1.5, 0.75],
        [0.75, 1.5]
    ]
    
    # Assign new values (same pattern as above)
    for i in range(num_sections):
        width_val = float_to_fixed(widths[i], FRAC_BITS)
        if has_signal(dut, f'widths_{i}'):
            getattr(dut, f'widths_{i}').value = clamp_to_width(width_val, DATA_WIDTH)
        elif has_signal(dut, 'widths'):
            dut.widths[i].value = clamp_to_width(width_val, DATA_WIDTH)
    
    for j in range(num_colors):
        vol_val = float_to_fixed(volumes[j], FRAC_BITS)
        if has_signal(dut, f'volumes_{j}'):
            getattr(dut, f'volumes_{j}').value = clamp_to_width(vol_val, DATA_WIDTH)
        elif has_signal(dut, 'volumes'):
            dut.volumes[j].value = clamp_to_width(vol_val, DATA_WIDTH)
    
    for i in range(num_sections):
        for j in range(num_colors):
            min_val = float_to_fixed(min_vals[i][j], FRAC_BITS)
            max_val = float_to_fixed(max_vals[i][j], FRAC_BITS)
            
            if has_signal(dut, f'min_vals_{i}_{j}'):
                getattr(dut, f'min_vals_{i}_{j}').value = clamp_to_width(min_val, DATA_WIDTH)
                getattr(dut, f'max_vals_{i}_{j}').value = clamp_to_width(max_val, DATA_WIDTH)
            elif has_signal(dut, f'min_vals_{i}'):
                dut.min_vals[i][j].value = clamp_to_width(min_val, DATA_WIDTH)
                dut.max_vals[i][j].value = clamp_to_width(max_val, DATA_WIDTH)
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
        if cycle == max_cycles - 1:
            raise TestFailure("Timeout waiting for done signal")
    
    # Read result
    if has_signal(dut, 'min_difference') and is_value_defined(dut.min_difference.value):
        result_fixed = int(dut.min_difference.value)
        result_float = fixed_to_float(result_fixed, FRAC_BITS)
        
        # Expected difference (approximately 0.625 in original, scaled ~0.3125)
        expected = 0.3125
        tolerance = 0.05
        if abs(result_float - expected) > tolerance:
            raise TestFailure(f"Expected ~{expected}, got {result_float}")
        
        dut._log.info(f"Test passed: difference = {result_float:.3f}")
    else:
        raise TestFailure("Cannot read min_difference signal")
    
    dut._log.info("All tests completed successfully!")
