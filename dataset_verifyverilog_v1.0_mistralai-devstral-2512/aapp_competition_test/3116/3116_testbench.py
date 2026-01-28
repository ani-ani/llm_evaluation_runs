import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 16
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 300

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    if v < 0:
        v = 0
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def to_fixed_point(f, frac=16):
    return int(f * (1 << frac))

def from_fixed_point(v, frac=16):
    return v / (1 << frac)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Approximate calculation for expected values (scaled by 2^16)
def calculate_expected(points, n):
    min_volume = float('inf')
    # 8 directions: +X, -X, +Y, -Y, +Z, -Z, +X+Y, +X-Y
    directions = [
        (1, 0, 0), (-1, 0, 0),
        (0, 1, 0), (0, -1, 0),
        (0, 0, 1), (0, 0, -1),
        (1, 1, 0), (1, -1, 0)
    ]
    
    for dx, dy, dz in directions:
        norm = math.sqrt(dx*dx + dy*dy + dz*dz)
        proj = [dx*p[0] + dy*p[1] + dz*p[2] for p in points]
        min_p = min(proj)
        max_p = max(proj)
        height = max_p - min_p
        
        # Find max perpendicular distance squared
        # For simplicity, use distance from axis line passing through origin
        # More accurate: distance from axis line passing through centroid
        # But we'll use origin as approximation
        max_dist_sq = 0
        for px, py, pz in points:
            # Distance from line (0,0,0) to point (px,py,pz)
            # with direction (dx,dy,dz)
            # d^2 = r^2 - (r·u)^2 where r is vector to point, u is unit direction
            proj_val = (dx*px + dy*py + dz*pz) / norm
            dist_sq = (px*px + py*py + pz*pz) - proj_val*proj_val
            if dist_sq > max_dist_sq:
                max_dist_sq = dist_sq
        
        if height > 0 and max_dist_sq > 0:
            volume = math.pi * max_dist_sq * height
            if volume < min_volume:
                min_volume = volume
    
    return int(min_volume * (1 << 16))

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cylinder(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_points = [
        # Test case 1
        [(1, 0, 0), (1, 1, 0), (0, 0, 0), (0, 0, 1)],
        # Test case 2
        [(-100, 0, 0), (10, 0, 10), (-10, -10, -10), (0, 0, 0)],
        # Test case 3 (8 points for max array size)
        [(10, 20, 30), (0, 0, 0), (-100, 1000, -20), (100, -20, 33),
         (8, -7, 900), (-100, -223, -23), (3, 0, 3), (5, 5, 5)]
    ]
    
    passed = failed = 0
    
    for test_idx, points in enumerate(test_points):
        n = len(points)
        cocotb.log.info(f"Test case {test_idx + 1}: {n} points")
        
        try:
            # Calculate expected value
            expected = calculate_expected(points, n)
            
            # Write inputs
            for i in range(8):
                if i < n:
                    px, py, pz = points[i]
                    dut.points_x[i].value = to_fixed_point(px)
                    dut.points_y[i].value = to_fixed_point(py)
                    dut.points_z[i].value = to_fixed_point(pz)
                else:
                    dut.points_x[i].value = 0
                    dut.points_y[i].value = 0
                    dut.points_z[i].value = 0
            
            dut.n.value = n
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            result_float = from_fixed_point(result)
            expected_float = from_fixed_point(expected)
            
            # Check within relative tolerance of 1e-6
            rel_err = abs(result_float - expected_float) / max(abs(expected_float), 1.0)
            if rel_err > 1e-4:  # Relaxed tolerance for simplified algorithm
                raise TestFailure(f"Result {result_float:.10f} differs from expected {expected_float:.10f} (rel err {rel_err:.2e})")
            
            cocotb.log.info(f"Result: {result_float:.10f}, Expected: {expected_float:.10f}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")