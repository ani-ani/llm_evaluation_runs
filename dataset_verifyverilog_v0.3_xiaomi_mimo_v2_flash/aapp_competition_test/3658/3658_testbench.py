import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, int(value)))

# ============================================================================
# FIXED-POINT HELPERS (Q16.16)
# ============================================================================

FRAC_BITS = 16
INT_BITS = 16

float_to_fixed = lambda f: int(f * (1 << FRAC_BITS))
fixed_to_float = lambda f: f / (1 << FRAC_BITS) if f < (1 << (INT_BITS+FRAC_BITS-1)) else (f - (1 << (INT_BITS+FRAC_BITS))) / (1 << FRAC_BITS)

# ============================================================================
# GEOMETRY HELPERS (Python reference)
# ============================================================================

def cross(ax, ay, bx, by):
    return ax * by - ay * bx

def signed_area(p1, p2, p3):
    return cross(p2[0]-p1[0], p2[1]-p1[1], p3[0]-p1[0], p3[1]-p1[1])

def orient_triangle(tri):
    if signed_area(tri[0], tri[1], tri[2]) < 0:
        return [tri[0], tri[2], tri[1]]
    return tri

def point_in_halfplane(p, edge_start, edge_end):
    # Check if point p is on the left side of edge from edge_start to edge_end
    return cross(edge_end[0]-edge_start[0], edge_end[1]-edge_start[1],
                 p[0]-edge_start[0], p[1]-edge_start[1]) >= 0

def line_intersection(p1, p2, q1, q2):
    # Compute intersection of lines p1-p2 and q1-q2
    # Returns (x, y) or None if parallel
    ux = p2[0] - p1[0]
    uy = p2[1] - p1[1]
    vx = q2[0] - q1[0]
    vy = q2[1] - q1[1]
    wx = p1[0] - q1[0]
    wy = p1[1] - q1[1]
    d = cross(ux, uy, vx, vy)
    if abs(d) < 1e-12:
        return None
    t = cross(vx, vy, wx, wy) / d
    return (p1[0] + t * ux, p1[1] + t * uy)

def sutherland_hodgman(poly, clip):
    # Clip polygon against convex clip polygon (clip is list of vertices)
    output = poly[:]
    for i in range(len(clip)):
        input_list = output[:]
        output = []
        if not input_list:
            break
        edge_start = clip[i]
        edge_end = clip[(i+1) % len(clip)]
        for j in range(len(input_list)):
            current = input_list[j]
            previous = input_list[j-1]
            # Check current point
            cur_in = point_in_halfplane(current, edge_start, edge_end)
            prev_in = point_in_halfplane(previous, edge_start, edge_end)
            if cur_in:
                if not prev_in:
                    # Intersection
                    inter = line_intersection(previous, current, edge_start, edge_end)
                    if inter:
                        output.append(inter)
                output.append(current)
            elif prev_in:
                inter = line_intersection(previous, current, edge_start, edge_end)
                if inter:
                    output.append(inter)
    return output

def polygon_area(poly):
    if len(poly) < 3:
        return 0.0
    area = 0.0
    for i in range(len(poly)):
        j = (i+1) % len(poly)
        area += poly[i][0] * poly[j][1] - poly[j][0] * poly[i][1]
    return abs(area) * 0.5

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_intersection_area(dut):
    """Test triangle intersection area computation."""
    
    # Configure
    CLK_PERIOD_NS = 10
    DATA_WIDTH = 32  # Q16.16
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.P.value = 0
    dut.A.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (pine_points, aspen_points, description)
    # Points are (x, y) as floats
    test_cases = [
        # Example 1: overlapping triangles
        (
            [(0.0, 6.0), (6.0, 0.0), (6.0, 6.0)],
            [(4.0, 4.0), (10.0, 4.0), (4.0, 10.0)],
            "Example 1: sample input"
        ),
        # Example 2: from problem statement
        (
            [(0.67, 10.82), (5.58, 5.43), (5.83, 10.79)],
            [(5.70, 15.06), (10.53, 10.05), (10.45, 5.22)],
            "Example 2: larger triangles"
        ),
        # Non-overlapping
        (
            [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0)],
            [(2.0, 2.0), (3.0, 2.0), (2.0, 3.0)],
            "Non-overlapping"
        ),
        # One triangle inside the other
        (
            [(0.0, 0.0), (10.0, 0.0), (0.0, 10.0)],
            [(1.0, 1.0), (2.0, 1.0), (1.0, 2.0)],
            "Small inside large"
        ),
    ]
    
    for idx, (pine_pts, aspen_pts, desc) in enumerate(test_cases):
        dut._log.info(f"\nTest {idx+1}: {desc}")
        
        # Convert to fixed-point
        pine_fp = [(float_to_fixed(x), float_to_fixed(y)) for x, y in pine_pts]
        aspen_fp = [(float_to_fixed(x), float_to_fixed(y)) for x, y in aspen_pts]
        
        # Assign to DUT
        dut.pine_x0.value = pine_fp[0][0]
        dut.pine_y0.value = pine_fp[0][1]
        dut.pine_x1.value = pine_fp[1][0]
        dut.pine_y1.value = pine_fp[1][1]
        dut.pine_x2.value = pine_fp[2][0]
        dut.pine_y2.value = pine_fp[2][1]
        
        dut.aspen_x0.value = aspen_fp[0][0]
        dut.aspen_y0.value = aspen_fp[0][1]
        dut.aspen_x1.value = aspen_fp[1][0]
        dut.aspen_y1.value = aspen_fp[1][1]
        dut.aspen_x2.value = aspen_fp[2][0]
        dut.aspen_y2.value = aspen_fp[2][1]
        
        dut.P.value = 3
        dut.A.value = 3
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 1000:
                raise TestFailure("Timeout waiting for done")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined")
        
        result_fp = int(dut.result.value)
        result_float = fixed_to_float(result_fp)
        
        # Compute expected area using Python reference
        triA = orient_triangle(pine_pts)
        triB = orient_triangle(aspen_pts)
        intersect_poly = sutherland_hodgman(triA, triB)
        expected_area = polygon_area(intersect_poly)
        
        dut._log.info(f"  Expected: {expected_area:.6f}, Got: {result_float:.6f}")
        
        # Check with tolerance (1e-3 absolute error)
        if abs(result_float - expected_area) > 1e-3 + 1e-6:
            raise TestFailure(f"Area mismatch: expected {expected_area:.6f}, got {result_float:.6f}")
    
    dut._log.info("\nAll tests passed!")
