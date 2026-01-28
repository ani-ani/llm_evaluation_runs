import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools

# Constants based on spec (N <= 16, 8-bit coords)
MAX_N = 16
COORD_WIDTH = 8
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 5000  # Safe timeout for O(N^3) logic

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_signed_8bit(val):
    if val < 0:
        return (1 << 8) + val
    return val

# Reference Python implementation for ground truth
def count_right_triangles_py(points):
    n = len(points)
    count = 0
    for i in range(n):
        for j in range(n):
            if i == j: continue
            for k in range(n):
                if k == i or k == j: continue
                # Vectors from i
                dx1 = points[j][0] - points[i][0]
                dy1 = points[j][1] - points[i][1]
                dx2 = points[k][0] - points[i][0]
                dy2 = points[k][1] - points[i][1]
                if dx1 * dx2 + dy1 * dy2 == 0:
                    count += 1
                    break  # Avoid double counting triangles, count per valid triplet once
    # The above counts ordered permutations where right angle is at first vertex.
    # The problem asks for number of triangles (sets of 3 points).
    # Let's implement strict triplet checking to match hardware logic.
    
    triangles = set()
    for i in range(n):
        for j in range(n):
            if i == j: continue
            for k in range(n):
                if k == i or k == j: continue
                p1, p2, p3 = points[i], points[j], points[k]
                # Check dot products for all 3 vertices
                # V1 = p2-p1, V2 = p3-p1
                if (p2[0]-p1[0])*(p3[0]-p1[0]) + (p2[1]-p1[1])*(p3[1]-p1[1]) == 0:
                    s = tuple(sorted([i, j, k]))
                    triangles.add(s)
    return len(triangles)

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1 << bits) - 1)) << (i * bits)
    return r

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_right_triangles(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test Cases: 3 points (1 triangle), 4 points (0 triangles), 5 points (7 triangles)
    # Coordinate range: -128 to 127 (8-bit signed)
    test_data = [
        {
            "points": [(4, 2), (2, 1), (1, 3)],
            "expected": 1,
            "name": "Simple 3 points"
        },
        {
            "points": [(5, 0), (2, 6), (8, 6), (5, 7)],
            "expected": 0,
            "name": "4 points no triangle"
        },
        {
            "points": [(-1, 1), (-1, 0), (0, 0), (1, 0), (1, 1)],
            "expected": 7,
            "name": "5 points grid"
        }
    ]
    
    for i, case in enumerate(test_data):
        cocotb.log.info(f"Running Test Case {i+1}: {case['name']}")
        points = case['points']
        n = len(points)
        expected = case['expected']
        
        # Clamp coordinates to 8-bit unsigned for transport (offset if negative)
        # Python handles negative natively, HDL expects 8-bit vectors.
        # We send raw 8-bit values. If HDL expects signed, we assume inputs are 8-bit signed.
        # For simplicity, we map -128..127 to 0..255 (offset binary) or just pass raw bit patterns.
        # Let's pass raw bit patterns (two's complement).
        xs = [to_signed_8bit(p[0]) for p in points]
        ys = [to_signed_8bit(p[1]) for p in points]
        
        # Pad arrays to size MAX_N (16) with 0
        xs += [0] * (MAX_N - n)
        ys += [0] * (MAX_N - n)
        
        # Write inputs
        if has_signal(dut, 'points_x'):
             # Assuming array of vectors [0:15] or specific naming
             # Support both packed array and individual signals
             try:
                 dut.points_x.value = pack_array(xs, 8)
                 dut.points_y.value = pack_array(ys, 8)
             except AttributeError:
                 # Individual signals
                 for idx in range(MAX_N):
                     getattr(dut, f'points_x_{idx}').value = xs[idx]
                     getattr(dut, f'points_y_{idx}').value = ys[idx]
        
        if has_signal(dut, 'num_points'):
            dut.num_points.value = n
            
        # Trigger
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, MAX_CYCLES)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result signal undefined")
            
        result = int(dut.result.value)
        cocotb.log.info(f"Expected: {expected}, Got: {result}")
        
        if result != expected:
            raise TestFailure(f"Test {i+1} failed. Expected {expected}, got {result}")
            
    cocotb.log.info("All tests passed!")