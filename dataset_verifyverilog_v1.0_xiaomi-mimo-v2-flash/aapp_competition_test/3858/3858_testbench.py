import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
from math import gcd

# Constants
MOD = 998244353
MAX_N = 200
CLK_NS = 10
MAX_CYCLES = 200000

# Helper functions
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

def pow2_mod(n, mod):
    return pow(2, n, mod)

def expected_result(points):
    """Compute expected result using Python"""
    n = len(points)
    if n < 3:
        return 0
    
    # Count total subsets: 2^n
    ans = pow2_mod(n, MOD)
    # Subtract non-polygons: empty (1), single points (n), pairs (n*(n-1)/2)
    ans = (ans - 1 - n - n*(n-1)//2) % MOD
    
    # Find collinear sets and subtract their subsets
    collinear_sets = {}
    for i in range(n):
        xi, yi = points[i]
        for j in range(i+1, n):
            xj, yj = points[j]
            dx = xj - xi
            dy = yj - yi
            
            # Count points on line i-j
            cnt = 2  # points i and j
            inline = {i, j}
            for k in range(n):
                if k == i or k == j:
                    continue
                xk, yk = points[k]
                # Check if k is on line i-j using cross product
                if dx * (yk - yi) == dy * (xk - xi):
                    cnt += 1
                    inline.add(k)
            
            if cnt > 2:
                # Store the set as a frozenset to deduplicate
                key = frozenset(inline)
                if key not in collinear_sets:
                    collinear_sets[key] = cnt
    
    # For each collinear set of size c > 2, subtract (2^c - c - 1)
    for cnt in collinear_sets.values():
        ans = (ans - (pow2_mod(cnt, MOD) - cnt - 1)) % MOD
    
    return ans

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_points(dut, points):
    """Load points into the module"""
    for i, (x, y) in enumerate(points):
        dut.point_index.value = i
        dut.x_i.value = clamp_to_width(x, 14)
        dut.y_i.value = clamp_to_width(y, 14)
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0

async def calculate_score(dut, points):
    """Run the calculation for given points"""
    # Load points
    await load_points(dut, points)
    
    # Start calculation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result
    result = int(dut.result.value)
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_convex_score(dut):
    # Check if module has required signals
    if not (has_signal(dut, 'clk') and has_signal(dut, 'rst_n') and 
            has_signal(dut, 'start') and has_signal(dut, 'done') and 
            has_signal(dut, 'result') and has_signal(dut, 'x_i') and 
            has_signal(dut, 'y_i') and has_signal(dut, 'point_index') and 
            has_signal(dut, 'valid_in')):
        raise TestFailure("Module missing required signals")
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (points, expected result, description)
    test_cases = [
        ([], 0, "Empty set"),
        ([(0, 0)], 0, "Single point"),
        ([(0, 0), (0, 1)], 0, "Two points"),
        ([(0, 0), (0, 1), (1, 0)], 0, "Three collinear points (2^3 - 3 - 1 = 4)"),
        ([(0, 0), (0, 1), (1, 0), (1, 1)], 5, "4 points, all triangles + square"),
        ([(0, 0), (0, 1), (0, 2)], 0, "3 collinear points"),
        ([(0, 0), (0, 1), (1, 0), (1, 1), (0.5, 0.5)], 1, "Point inside convex hull"),
    ]
    
    passed = failed = 0
    
    for i, (points, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} ({len(points)} points)")
        try:
            # Run calculation
            result = await calculate_score(dut, points)
            
            # Expected value
            exp = expected_result(points)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            cocotb.log.info(f"  Result: {result} (correct)")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_large_n(dut):
    """Test with larger N values from sample inputs"""
    # Sample test cases from the problem
    sample_tests = [
        ([], 0, "Empty"),
    ]
    
    # Run additional tests
    for n in [4, 5, 8, 10]:
        if n > 0:
            # Generate points (simulating test case)
            points = [(i, i*2) for i in range(n)]  # Simple pattern
            
            cocotb.log.info(f"Testing N={n} with generic points")
            result = await calculate_score(dut, points)
            exp = expected_result(points)
            
            if result != exp:
                raise TestFailure(f"N={n}: Expected {exp}, got {result}")
            
            await reset_dut(dut)
    
    cocotb.log.info("All large N tests passed")
