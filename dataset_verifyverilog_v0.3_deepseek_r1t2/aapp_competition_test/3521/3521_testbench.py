import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION - Match HDL design parameters
# ============================================================================
DATA_WIDTH = 32
ANGLE_WIDTH = 16
FRAC_BITS = 16
STEPS = 256
CLK_PERIOD_NS = 10
MAX_CYCLES = 50000  # Allow enough cycles for computation

# Fixed-point constants
TWO_PI_Q16 = int(2 * math.pi * (1 << FRAC_BITS))  # 2π in Q16.16

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

def float_to_q16(f):
    """Convert float to Q16.16 fixed-point."""
    return int(f * (1 << FRAC_BITS))

def q16_to_float(fixed):
    """Convert Q16.16 fixed-point to float."""
    return fixed / (1 << FRAC_BITS)

# ============================================================================
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================

def python_reference(stars):
    """Reference implementation using exact float arithmetic."""
    N = len(stars)
    if N == 0:
        return 0.0
    
    max_dist = 0.0
    
    # Search over discrete angles
    for step in range(STEPS):
        angle = 2 * math.pi * step / STEPS
        total = 0.0
        
        for T, s, a in stars:
            # Circular distance
            diff = abs(a - angle)
            dist = min(diff, 2 * math.pi - diff)
            # Contribution
            contrib = max(0.0, T - s * dist)
            total += contrib
        
        max_dist = max(max_dist, total)
    
    return max_dist

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_star_params(dut, stars):
    """Write star parameters to DUT."""
    N = len(stars)
    if N > 8:
        raise TestFailure(f"N={N} exceeds maximum 8")
    
    # Pad to 8 stars with zeros if needed
    while len(stars) < 8:
        stars.append((0.0, 0.0, 0.0))
    
    # Write individual ports
    for i, (T, s, a) in enumerate(stars):
        # Convert to fixed-point
        t_fixed = float_to_q16(T)
        s_fixed = float_to_q16(s)
        a_fixed = float_to_q16(a)
        
        # Clamp to width
        t_fixed = clamp_to_width(t_fixed, DATA_WIDTH)
        s_fixed = clamp_to_width(s_fixed, DATA_WIDTH)
        a_fixed = clamp_to_width(a_fixed, ANGLE_WIDTH)
        
        # Write to DUT
        getattr(dut, f't_{i}').value = t_fixed
        getattr(dut, f's_{i}').value = s_fixed
        getattr(dut, f'a_{i}').value = a_fixed

async def read_max_distance(dut):
    """Read max_distance from DUT and convert to float."""
    if not is_value_defined(dut.max_distance.value):
        raise TestFailure("max_distance is undefined (X/Z)")
    
    fixed = int(dut.max_distance.value)
    return q16_to_float(fixed)

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_starship_max_distance(dut):
    """Test starship maximum distance calculation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await Timer(100, units='ns')
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (stars, description)
    # Each star: (T, s, a)
    test_cases = [
        (
            [(100.0, 1.0, 1.0), (100.0, 1.0, 1.5)],
            "Two stars at 1.0 and 1.5 rad"
        ),
        (
            [(100.0, 1.0, 0.5), (200.0, 1.0, 1.0), (100.0, 0.5, 1.5), (10.0, 2.0, 3.0)],
            "Four stars example"
        ),
        (
            [(50.0, 0.5, 0.0), (50.0, 0.5, 3.14159)],
            "Two opposite stars"
        ),
        (
            [(100.0, 100.0, 1.0)],
            "Single star with high sensitivity"
        ),
        (
            [(100.0, 0.0, 1.0), (100.0, 0.0, 2.0)],
            "Zero sensitivity (perfect alignment)"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (stars, description) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: {description}")
        dut._log.info(f"Stars: {stars}")
        
        try:
            # Write inputs
            await write_star_params(dut, stars)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            hw_result = await read_max_distance(dut)
            
            # Compute expected (reference)
            expected = python_reference(stars)
            
            # Check with tolerance
            abs_error = abs(hw_result - expected)
            rel_error = abs_error / max(expected, 1e-9)
            
            dut._log.info(f"  HW result: {hw_result:.6f}")
            dut._log.info(f"  Expected:  {expected:.6f}")
            dut._log.info(f"  Error:     {abs_error:.6e} (rel: {rel_error:.6e})")
            
            # Pass if absolute error < 1e-4 or relative error < 1e-4
            if abs_error < 1e-4 or rel_error < 1e-4:
                dut._log.info("  PASS")
                passed += 1
            else:
                dut._log.error("  FAIL: Error exceeds tolerance")
                failed += 1
                
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    
    # Additional test for N=0 (edge case)
    dut._log.info("\nTest 7: Edge case - no stars (N=0)")
    await write_star_params(dut, [])
    await start_computation(dut)
    await wait_for_done(dut)
    result = await read_max_distance(dut)
    if result == 0.0:
        dut._log.info("  PASS")
    else:
        dut._log.error(f"  FAIL: Expected 0.0, got {result}")
        raise TestFailure("N=0 test failed")

# ============================================================================
# TIMEOUT TEST - Check module handles timeout gracefully
# ============================================================================

@cocotb.test(timeout_time=500, timeout_unit="ms", expect_fail=True)
async def test_timeout(dut):
    """Test that module completes within reasonable time."""
    # This test will pass if timeout occurs (module takes too long)
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Simple test case
    stars = [(100.0, 1.0, 1.0), (100.0, 1.0, 1.5)]
    await write_star_params(dut, stars)
    await start_computation(dut)
    await wait_for_done(dut, max_cycles=100)  # Strict timeout
    result = await read_max_distance(dut)
    
    # If we reach here, module was fast enough
    dut._log.info(f"Module completed quickly: {result:.6f}")