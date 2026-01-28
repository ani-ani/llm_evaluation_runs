import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools
import math

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Helper to calculate distance (Python reference)
def calc_dist(x1, y1, x2, y2):
    return math.sqrt((x2-x1)**2 + (y2-y1)**2)

def is_convex(pts):
    # pts is list of (x,y) tuples
    n = len(pts)
    if n < 3: return False
    prev_cross = 0
    for i in range(n):
        p1 = pts[i]
        p2 = pts[(i+1)%n]
        p3 = pts[(i+2)%n]
        v1x = p2[0] - p1[0]
        v1y = p2[1] - p1[1]
        v2x = p3[0] - p2[0]
        v2y = p3[1] - p2[1]
        cross = v1x * v2y - v1y * v2x
        if cross == 0: return False # Collinear
        if prev_cross == 0:
            prev_cross = cross
        elif (cross > 0) != (prev_cross > 0):
            return False
    return True

def get_perimeter(pts):
    perim = 0.0
    n = len(pts)
    for i in range(n):
        p1 = pts[i]
        p2 = pts[(i+1)%n]
        perim += calc_dist(p1[0], p1[1], p2[0], p2[1])
    return perim

def python_solve(n, coords):
    # Returns list of max perimeters for each vertex index 0..n-1
    res = [0.0] * n
    for i in range(n):
        best = 0.0
        # Vertices to choose from (excluding i)
        others = [j for j in range(n) if j != i]
        # Generate combinations of 5 others
        for combo in itertools.permutations(others, 5):
            pts = [coords[i]] + [coords[j] for j in combo]
            if is_convex(pts):
                p = get_perimeter(pts)
                if p > best:
                    best = p
        res[i] = best
    return res

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_hamster_wall(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    CLK_NS = 10
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')

    # Test cases
    # Case 1: n=6 (as per sample)
    # Note: The hardware module is limited to n=8, but the original problem allows up to 2000.
    # Since we scaled down n <= 8, we test with n=6 and n=8.
    # For n=6, python_solve finds the only hexagon.
    
    test_inputs = [
        (6, [(1,2), (1,3), (2,4), (3,3), (3,2), (2,1)]),
        (8, [(3,1), (6,1), (8,3), (8,6), (6,8), (3,8), (1,6), (1,3)])
    ]
    
    for n, coords in test_inputs:
        if n > 8:
            cocotb.log.warning(f"Skipping n={n} > 8 (HW limit)")
            continue
        
        expected = python_solve(n, coords)
        cocotb.log.info(f"Testing n={n}, Expected: {expected}")
        
        # Load inputs
        dut.n_in.value = n
        for i in range(8): # Clear first
            if hasattr(dut, 'coord_x'):
                dut.coord_x[i].value = 0
            if hasattr(dut, 'coord_y'):
                dut.coord_y[i].value = 0
                
        for i in range(n):
            x, y = coords[i]
            # Handle packed array or individual signals
            if hasattr(dut, 'coord_x'):
                dut.coord_x[i].value = x & 0xFFFF
                dut.coord_y[i].value = y & 0xFFFF
            elif hasattr(dut, 'coord_x_0'): # Individual ports
                getattr(dut, f'coord_x_{i}').value = x & 0xFFFF
                getattr(dut, f'coord_y_{i}').value = y & 0xFFFF
        
        # Start computation
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Read results
            found_results = [0.0] * n
            read_count = 0
            max_cycles = 100000
            
            for _ in range(max_cycles):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    # Read result and vertex_idx
                    if is_value_defined(dut.result.value):
                        raw_res = int(dut.result.value)
                        # Convert from fixed point Q16.16
                        # Note: raw_res is integer representing fixed point
                        val = fixed_to_float(raw_res)
                        
                        # Check vertex index
                        if is_value_defined(dut.vertex_idx.value):
                            v_idx = int(dut.vertex_idx.value)
                            if v_idx < n:
                                found_results[v_idx] = val
                                read_count += 1
                                cocotb.log.info(f"Got result for vertex {v_idx}: {val}")
                                if read_count == n:
                                    break
        else:
            # Combinational logic
            await Timer(1000, units='ns')
            # For combinational, we would check outputs directly
            # But this problem is inherently sequential with loops, so we assume sequential
            pass

        # Verification
        if is_seq:
            if read_count != n:
                raise TestFailure(f"Only read {read_count} results, expected {n}")
            
            for i in range(n):
                # Allow tolerance for fixed-point errors
                if abs(found_results[i] - expected[i]) > 0.1:
                    raise TestFailure(f"Vertex {i}: Got {found_results[i]}, Expected {expected[i]}")

    cocotb.log.info("All tests passed")