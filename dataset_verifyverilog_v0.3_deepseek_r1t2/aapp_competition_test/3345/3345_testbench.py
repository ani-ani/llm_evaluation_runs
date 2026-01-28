import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        float(value)
        return True
    except ValueError:
        return False

def safe_float(value, default=0.0):
    """Safely convert cocotb value to float, returning default if X/Z."""
    try:
        return float(value)
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# EXPECTED MIN DISTANCE FUNCTION (same algorithm as Verilog)
# ============================================================================

def expected_min_distance(shadow_x0, shadow_y0, shadow_x1, shadow_y1,
                         lydia_x0, lydia_y0, lydia_x1, lydia_y1):
    """Compute minimum distance between two dogs walking along straight segments."""
    # Differences
    dx_s = shadow_x1 - shadow_x0
    dy_s = shadow_y1 - shadow_y0
    dx_l = lydia_x1 - lydia_x0
    dy_l = lydia_y1 - lydia_y0

    # Lengths
    Ls = math.sqrt(dx_s*dx_s + dy_s*dy_s)
    Ll = math.sqrt(dx_l*dx_l + dy_l*dy_l)

    # T = min(Ls, Ll)
    T = min(Ls, Ll)

    # Unit vectors
    if Ls > 0:
        u_x = dx_s / Ls
        u_y = dy_s / Ls
    else:
        u_x = 0
        u_y = 0

    if Ll > 0:
        v_x = dx_l / Ll
        v_y = dy_l / Ll
    else:
        v_x = 0
        v_y = 0

    # C = start difference
    C_x = shadow_x0 - lydia_x0
    C_y = shadow_y0 - lydia_y0

    # w = u - v
    w_x = u_x - v_x
    w_y = u_y - v_y

    # a, b, c
    a = w_x*w_x + w_y*w_y
    b = 2 * (C_x*w_x + C_y*w_y)
    c = C_x*C_x + C_y*C_y

    # Candidates
    f0 = c
    fT = a*T*T + b*T + c

    min_f = f0
    if fT < min_f:
        min_f = fT

    if a > 0:
        t0 = -b / (2*a)
        if t0 >= 0 and t0 <= T:
            ft0 = c - b*b/(4*a)
            if ft0 < min_f:
                min_f = ft0

    # Return minimum distance (sqrt of min_f)
    if min_f >= 0:
        return math.sqrt(min_f)
    else:
        return 0.0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_min_distance_dogs(dut):
    """Test the min_distance_dogs module with multiple test cases."""
    
    # Define test cases: (shadow_start, shadow_end, lydia_start, lydia_end, expected_min)
    # Each point is (x, y)
    test_cases = [
        # Example 1: both horizontal, meeting at end
        ((0,0), (10,0), (30,0), (15,0), 10.0),
        # Example 2: constant distance 10
        ((0,0), (10,0), (0,10), (10,10), 10.0),
        # Example 3: diagonal crossing, distance 0 at middle
        ((0,0), (10,10), (10,0), (0,10), 0.0),
        # Example 4: different lengths, constant distance
        ((0,0), (10,0), (0,10), (20,10), 10.0),
        # Example 5: approaching and receding, minimum at interior
        ((0,0), (10,0), (0,0), (0,10), 7.0710678118654755),
    ]
    
    passed = 0
    failed = 0
    
    for i, (shadow_start, shadow_end, lydia_start, lydia_end, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Shadow {shadow_start}->{shadow_end}, Lydia {lydia_start}->{lydia_end}")
        
        # Set inputs
        dut.shadow_x0.value = shadow_start[0]
        dut.shadow_y0.value = shadow_start[1]
        dut.shadow_x1.value = shadow_end[0]
        dut.shadow_y1.value = shadow_end[1]
        dut.lydia_x0.value = lydia_start[0]
        dut.lydia_y0.value = lydia_start[1]
        dut.lydia_x1.value = lydia_end[0]
        dut.lydia_y1.value = lydia_end[1]
        
        # Wait for combinational logic to settle (1 ns)
        await Timer(1, units='ns')
        
        # Read output
        if not is_value_defined(dut.min_dist.value):
            raise TestFailure(f"Output min_dist is undefined (X/Z)")
        
        actual = safe_float(dut.min_dist.value)
        
        # Compare with tolerance
        tolerance = 1e-4
        if abs(actual - expected) > tolerance:
            raise TestFailure(f"Expected {expected}, got {actual}")
        
        cocotb.log.info(f"  PASS: distance = {actual}")
        passed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")