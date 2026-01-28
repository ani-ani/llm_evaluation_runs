import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Fixed point conversion
FIXED_BITS = 16
SCALE = 1 << FIXED_BITS

def float_to_fixed(f):
    return int(f * SCALE)

def fixed_to_float(v):
    # Handle sign extension if v is passed as a signed integer
    if v >= (1<<31): v -= (1<<32)
    return v / SCALE

# Python reference implementation for testing
def cross_product(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

def convex_hull(points):
    points = sorted(points)
    if len(points) <= 1:
        return points
    lower = []
    for p in points:
        while len(lower) >= 2 and cross_product(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    upper = []
    for p in reversed(points):
        while len(upper) >= 2 and cross_product(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]

def inside(p, edge_start, edge_end):
    cp = (edge_end[0] - edge_start[0]) * (p[1] - edge_start[1]) - (edge_end[1] - edge_start[1]) * (p[0] - edge_start[0])
    return cp <= 0  # Inside or on edge (CCW winding assumption changes this, adjust based on hull order)

def line_intersection(p, s, edge_start, edge_end):
    dx = edge_end[0] - edge_start[0]
    dy = edge_end[1] - edge_start[1]
    if dx == 0 and dy == 0:
        return s
    # Using standard line intersection formula
    # P1 + t(P2-P1) = Q1 + u(Q2-Q1)
    # t = ((Q1-Q2) x (Q1-P1)) / ((P2-P1) x (Q2-Q1))
    # u = ((P1-P2) x (P1-Q1)) / ((P2-P1) x (Q2-Q1))
    
    denom = dx * (s[1] - p[1]) - dy * (s[0] - p[0])
    if abs(denom) < 1e-9:
        return s
        
    t_num = dx * (edge_start[1] - p[1]) - dy * (edge_start[0] - p[0])
    t = t_num / denom
    
    return (p[0] + t * (s[0] - p[0]), p[1] + t * (s[1] - p[1]))

def sutherland_hodgman(subject_poly, clip_poly):
    if not subject_poly or not clip_poly:
        return []
    
    output = subject_poly[:]
    for i in range(len(clip_poly)):
        clip_edge_start = clip_poly[i]
        clip_edge_end = clip_poly[(i + 1) % len(clip_poly)]
        input_list = output[:]
        output = []
        if not input_list:
            break
            
        s = input_list[-1]
        for p in input_list:
            # Check if point is inside
            # For CCW hull, inside is to the left of the edge (cross product > 0)
            # Edge is from clip_edge_start to clip_edge_end
            edge_vec = (clip_edge_end[0] - clip_edge_start[0], clip_edge_end[1] - clip_edge_start[1])
            point_vec = (p[0] - clip_edge_start[0], p[1] - clip_edge_start[1])
            cross_val = edge_vec[0] * point_vec[1] - edge_vec[1] * point_vec[0]
            inside_p = cross_val <= 0 # Assuming CW order or relaxed check, need to be careful here.
            
            # Standard Sutherland-Hodgman logic
            # We need to determine the winding order of the polygon to know what "inside" means.
            # Usually, if polygons are CW, 'inside' means the point is to the right of the edge.
            # Let's rely on the mathematical definition: Is the intersection point between s and p within the clip edge?
            
            # Let's try the robust method: Check if s and p are on the 'inside' side of the edge.
            # Defining inside as: Cross(Edge, Point - Start) <= 0 (Right-hand rule usually)
            # If input poly is CCW, then inside is Left (Cross > 0). 
            # Since input ordering depends on sorting, let's try a generic clip check.
            
            # Actually, let's use a simpler check: Does the line segment (s,p) cross the edge (start,end)?
            # We calculate intersection if one is inside and one is outside.
            
            # Let's use the standard computational geometry check:
            # is_right(p, edge_start, edge_end) returns true if p is to the right.
            def is_right(p, a, b):
                return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]) < 0
            
            # Note: The winding of the hull depends on the sorting. 
            # Convex Hull typically produces CW or CCW. 
            # Let's assume standard output is CCW (mathematically positive area).
            # For Sutherland-Hodgman (Clip Subject against Clip), we check if points are inside the Clip polygon.
            # If Clip is CCW, 'inside' means to the LEFT of the edge.
            
            s_inside = not is_right(s, clip_edge_start, clip_edge_end)
            p_inside = not is_right(p, clip_edge_start, clip_edge_end)
            
            if p_inside:
                if not s_inside:
                    inter = line_intersection(s, p, clip_edge_start, clip_edge_end)
                    output.append(inter)
                output.append(p)
            elif s_inside:
                inter = line_intersection(s, p, clip_edge_start, clip_edge_end)
                output.append(inter)
            s = p
            
    return output

def poly_area(poly):
    if len(poly) < 3:
        return 0.0
    area = 0.0
    for i in range(len(poly)):
        j = (i + 1) % len(poly)
        area += poly[i][0] * poly[j][1]
        area -= poly[j][0] * poly[i][1]
    return abs(area) / 2.0

def reference_logic(pine_pts, aspen_pts, pine_cnt, aspen_cnt):
    pine_hull = convex_hull(pine_pts[:pine_cnt])
    aspen_hull = convex_hull(aspen_pts[:aspen_cnt])
    
    # Check if hulls are valid
    if len(pine_hull) < 3 or len(aspen_hull) < 3:
        # Simple intersection test for degenerate cases (line/point)
        # For this problem, we expect triangles or polygons.
        return 0.0
        
    intersection_poly = sutherland_hodgman(pine_hull, aspen_hull)
    return poly_area(intersection_poly)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_geo_area_intersect(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Sample Input
    # 3 Pine: (0,6), (6,0), (6,6) -> Right triangle
    # 3 Aspen: (4,4), (10,4), (4,10) -> Right triangle
    # Intersection is a square (4,4) to (6,6) -> Area = 4.0
    
    pine_inputs = [(0.0, 6.0), (6.0, 0.0), (6.0, 6.0)]
    aspen_inputs = [(4.0, 4.0), (10.0, 4.0), (4.0, 10.0)]
    
    pine_cnt = 3
    aspen_cnt = 3
    
    # Scale inputs
    pine_x_vals = [float_to_fixed(p[0]) for p in pine_inputs]
    pine_y_vals = [float_to_fixed(p[1]) for p in pine_inputs]
    aspen_x_vals = [float_to_fixed(p[0]) for p in aspen_inputs]
    aspen_y_vals = [float_to_fixed(p[1]) for p in aspen_inputs]
    
    # Pad with zeros for unused inputs
    while len(pine_x_vals) < 8:
        pine_x_vals.append(0)
        pine_y_vals.append(0)
    while len(aspen_x_vals) < 8:
        aspen_x_vals.append(0)
        aspen_y_vals.append(0)
        
    # Assign inputs
    for i in range(8):
        dut.pine_pts_x[i].value = clamp_to_width(pine_x_vals[i], 32)
        dut.pine_pts_y[i].value = clamp_to_width(pine_y_vals[i], 32)
        dut.aspen_pts_x[i].value = clamp_to_width(aspen_x_vals[i], 32)
        dut.aspen_pts_y[i].value = clamp_to_width(aspen_y_vals[i], 32)
        
    dut.pine_count.value = pine_cnt
    dut.aspen_count.value = aspen_cnt
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 10000
    done = False
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
            
    if not done:
        raise TestFailure(f"Timeout waiting for done signal")
        
    # Read result
    result_val = int(dut.area_out.value)
    result_float = fixed_to_float(result_val)
    
    # Calculate expected
    expected = reference_logic(pine_inputs, aspen_inputs, pine_cnt, aspen_cnt)
    
    # Check
    error = abs(result_float - expected)
    rel_error = error / expected if expected > 1e-9 else error
    
    cocotb.log.info(f"Result: {result_float} (Fixed: {result_val})")
    cocotb.log.info(f"Expected: {expected}")
    cocotb.log.info(f"Error: {error}")
    
    if error > 0.1 and rel_error > 0.01:
        raise TestFailure(f"Result mismatch: got {result_float}, expected {expected}")
