import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
FRAC_BITS = 16
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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def float_to_fixed(f, frac_bits=FRAC_BITS):
    """Convert float to fixed-point integer."""
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=FRAC_BITS):
    """Convert fixed-point integer to float."""
    return fixed / (1 << frac_bits)

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# GEOMETRY COMPUTATION (Python reference)
# ============================================================================

def compute_laser_tag(x1, y1, x2, y2, x3, y3):
    """
    Compute the range of y-values on wall (x=0) that can be hit.
    Returns: (low, high, low_inf, high_inf, can_hit)
    """
    # Mirror line coefficients
    A = y2 - y1
    B = x1 - x2
    C = -(A*x1 + B*y1)
    
    # D = A*x3 + B*y3 + C
    D = A*x3 + B*y3 + C
    
    # Denominator
    denom = A*A + B*B
    
    # Virtual shooter position
    if denom == 0:
        return (0, 0, False, False, False)
    
    Sx = x3 - (2*A*D)/denom
    Sy = y3 - (2*B*D)/denom
    
    # Check if mirror is between virtual shooter and wall
    x_min = min(x1, x2)
    x_max = max(x1, x2)
    
    if Sx > 0:
        if x_min >= Sx or x_max <= 0:
            return (0, 0, False, False, False)
    elif Sx < 0:
        if x_max <= Sx or x_min >= 0:
            return (0, 0, False, False, False)
    else:  # Sx == 0
        return (0, 0, False, False, False)
    
    # Compute for each endpoint
    y_vals = []
    inf_flags = []
    inf_dirs = []  # True for positive infinity, False for negative
    
    for xm, ym in [(x1, y1), (x2, y2)]:
        dx = xm - Sx
        dy = ym - Sy
        
        if abs(dx) < 1e-10:  # Treat as zero
            inf_flags.append(True)
            inf_dirs.append(dy > 0)
            y_vals.append(0)
        else:
            t = -Sx / dx
            y_wall = Sy + t * dy
            inf_flags.append(False)
            inf_dirs.append(False)
            y_vals.append(y_wall)
    
    # Determine range
    if inf_flags[0] and inf_flags[1]:
        low_inf = not inf_dirs[0]  # If both positive, low is negative-infinity
        high_inf = inf_dirs[1]
        low = 0
        high = 0
    elif inf_flags[0]:
        low_inf = True
        high_inf = False
        low = 0
        high = y_vals[1]
    elif inf_flags[1]:
        low_inf = False
        high_inf = True
        low = y_vals[0]
        high = 0
    else:
        low_inf = False
        high_inf = False
        low = min(y_vals)
        high = max(y_vals)
    
    return (low, high, low_inf, high_inf, True)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_laser_tag(dut):
    """Test laser_tag module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # Format: (x1, y1, x2, y2, x3, y3, expected_low, expected_high, expected_low_inf, expected_high_inf, expected_can_hit, description)
        (5, 10, 10, 10, 10, 0, 0, 0, True, False, True, "Example 1: horizontal mirror"),
        (5, 10, 10, 5, 10, 0, 5, 12.5, False, False, True, "Example 2: sloped mirror"),
        (6, 10, 10, 10, 10, 0, 0, 0, True, False, True, "Example 3: shorter horizontal mirror"),
        (10, 10, 20, 20, 20, 10, 0, 0, False, False, False, "Can't hit wall"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (x1, y1, x2, y2, x3, y3, exp_low, exp_high, exp_low_inf, exp_high_inf, exp_can_hit, desc) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {desc}")
        
        # Convert to fixed-point
        fx1 = float_to_fixed(x1)
        fy1 = float_to_fixed(y1)
        fx2 = float_to_fixed(x2)
        fy2 = float_to_fixed(y2)
        fx3 = float_to_fixed(x3)
        fy3 = float_to_fixed(y3)
        
        # Write inputs
        dut.x1.value = fx1
        dut.y1.value = fy1
        dut.x2.value = fx2
        dut.y2.value = fy2
        dut.x3.value = fx3
        dut.y3.value = fy3
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout waiting for done")
        
        # Read outputs
        low_fx = safe_int(dut.low_y.value)
        high_fx = safe_int(dut.high_y.value)
        low_inf = safe_int(dut.low_inf.value)
        high_inf = safe_int(dut.high_inf.value)
        can_hit = safe_int(dut.can_hit.value)
        
        # Convert back to float
        low = fixed_to_float(low_fx)
        high = fixed_to_float(high_fx)
        
        # Verify
        if can_hit != exp_can_hit:
            dut._log.error(f"  FAIL: can_hit = {can_hit}, expected {exp_can_hit}")
            failed += 1
            continue
        
        if not exp_can_hit:
            dut._log.info(f"  PASS: correctly determined can't hit wall")
            passed += 1
            continue
        
        # Check infinities
        if low_inf != exp_low_inf:
            dut._log.error(f"  FAIL: low_inf = {low_inf}, expected {exp_low_inf}")
            failed += 1
            continue
        
        if high_inf != exp_high_inf:
            dut._log.error(f"  FAIL: high_inf = {high_inf}, expected {exp_high_inf}")
            failed += 1
            continue
        
        # Check numeric values (with tolerance)
        if not exp_low_inf and abs(low - exp_low) > 0.0001:
            dut._log.error(f"  FAIL: low = {low}, expected {exp_low}")
            failed += 1
            continue
        
        if not exp_high_inf and abs(high - exp_high) > 0.0001:
            dut._log.error(f"  FAIL: high = {high}, expected {exp_high}")
            failed += 1
            continue
        
        dut._log.info(f"  PASS")
        passed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")