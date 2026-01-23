import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 64
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000
FRAC_BITS = 48  # Q16.48 format

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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    if value < 0:
        return 0
    return min(max_val, value)

# ============================================================================
# FIXED-POINT CONVERSION
# ============================================================================

def float_to_q16_48(f):
    """Convert float to Q16.48 fixed-point format."""
    return int(f * (1 << FRAC_BITS))

def q16_48_to_float(fixed):
    """Convert Q16.48 fixed-point to float."""
    return fixed / (1 << FRAC_BITS)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for _ in range(cycles):
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

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================

def solve_archimedes(b, tx, ty):
    """Reference Python implementation for validation."""
    # This is a simplified version for testing
    # The actual algorithm would find the point where tangent hits target
    
    # For this benchmark, we'll use a simplified approach:
    # Find phi such that the tangent at (b*phi*cos(phi), b*phi*sin(phi))
    # passes through (tx, ty)
    
    best_phi = 0
    min_error = float('inf')
    
    # Search range: from 2π to 10π (sufficient for most cases)
    phi_start = 2 * math.pi
    phi_end = 10 * math.pi
    step = 0.001
    
    phi = phi_start
    while phi <= phi_end:
        # Point on spiral
        x = b * phi * math.cos(phi)
        y = b * phi * math.sin(phi)
        
        # Tangent vector (derivative)
        dx = b * (math.cos(phi) - phi * math.sin(phi))
        dy = b * (math.sin(phi) + phi * math.cos(phi))
        
        # Distance from target to tangent line
        # Line: (x, y) + t*(dx, dy)
        # Distance = |(ty - y)*dx - (tx - x)*dy| / sqrt(dx^2 + dy^2)
        if dx != 0 or dy != 0:
            numerator = abs((ty - y) * dx - (tx - x) * dy)
            denominator = math.sqrt(dx*dx + dy*dy)
            error = numerator / denominator
            
            if error < min_error:
                min_error = error
                best_phi = phi
        
        phi += step
    
    x_result = b * best_phi * math.cos(best_phi)
    y_result = b * best_phi * math.sin(best_phi)
    
    return x_result, y_result

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_archimedes_spiral(dut):
    """Test the Archimedes spiral module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (b, tx, ty, expected_x, expected_y, description)
    test_cases = [
        (0.5, -5.301, 3.098, -1.26167861, 3.88425357, "Example 1"),
        (0.5, 8, 8, 9.21068947, 2.56226688, "Example 2"),
        (1, 8, 8, 6.22375968, -0.31921472, "Example 3"),
        (0.5, -8, 8, -4.36385220, 9.46891588, "Example 4"),
        (0.5, 0, -8, -3.60855706, -3.61140618, "Example 5"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (b, tx, ty, exp_x, exp_y, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: b={b}, target=({tx}, {ty})")
        cocotb.log.info(f"  Expected: ({exp_x}, {exp_y})")
        
        try:
            # Convert to Q16.48
            b_fix = float_to_q16_48(b)
            tx_fix = float_to_q16_48(tx)
            ty_fix = float_to_q16_48(ty)
            
            # Set inputs
            dut.b.value = b_fix
            dut.tx.value = tx_fix
            dut.ty.value = ty_fix
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read outputs
            if not is_value_defined(dut.x.value) or not is_value_defined(dut.y.value):
                raise TestFailure("Output contains undefined values (X/Z)")
            
            x_result = q16_48_to_float(int(dut.x.value))
            y_result = q16_48_to_float(int(dut.y.value))
            
            # Compute reference using Python
            ref_x, ref_y = solve_archimedes(b, tx, ty)
            
            # Check error
            x_error = abs(x_result - exp_x)
            y_error = abs(y_result - exp_y)
            x_rel_error = x_error / abs(exp_x) if exp_x != 0 else x_error
            y_rel_error = y_error / abs(exp_y) if exp_y != 0 else y_error
            
            cocotb.log.info(f"  Result: ({x_result:.8f}, {y_result:.8f})")
            cocotb.log.info(f"  Error: |x|={x_error:.2e}, |y|={y_error:.2e}")
            cocotb.log.info(f"  Rel Error: |x|={x_rel_error:.2e}, |y|={y_rel_error:.2e}")
            
            # Check against requirements (1e-5 absolute or relative error)
            if x_error > 1e-5 and x_rel_error > 1e-5:
                raise TestFailure(f"X error too large: abs={x_error:.2e}, rel={x_rel_error:.2e}")
            if y_error > 1e-5 and y_rel_error > 1e-5:
                raise TestFailure(f"Y error too large: abs={y_error:.2e}, rel={y_rel_error:.2e}")
            
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
