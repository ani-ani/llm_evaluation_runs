import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Constants
DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 2000
MAX_POINTS = 16

# --- Helpers ---
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    mask = (1 << bits) - 1
    return v & mask

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done signal")

# --- Geometry Logic (Python Reference) ---
def cross_product(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

def convex_hull(points):
    points = sorted(set(points))
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

def get_edges(hull):
    n = len(hull)
    edges = []
    for i in range(n):
        p1 = hull[i]
        p2 = hull[(i+1)%n]
        edges.append((p2[0]-p1[0], p2[1]-p1[1]))
    return edges

def normalize_edges(edges):
    if not edges: return []
    # Rotate edges so first edge is horizontal (positive X)
    # Find rotation angle of first edge
    dx, dy = edges[0]
    if dx == 0 and dy == 0:
        return []
    # Normalize to (1, 0) direction for first edge
    # Simply check if subsequent edges match relative geometry
    return edges

def check_congruent(h1, h2):
    if len(h1) != len(h2):
        return False
    if len(h1) < 3:
        # Degenerate case: check lengths
        if len(h1) == 2:
            d1 = (h1[1][0]-h1[0][0])**2 + (h1[1][1]-h1[0][1])**2
            d2 = (h2[1][0]-h2[0][0])**2 + (h2[1][1]-h2[0][1])**2
            return d1 == d2
        return True # Single point or collinear
    
    e1 = get_edges(h1)
    e2 = get_edges(h2)
    
    # Check signatures
    # We need to allow rotation. 
    # Signature: (edge_len_sq, cross_product_with_next, dot_product_with_next)
    # Scale coordinates to fit 16-bit? The Python ref uses raw ints.
    # HDL will use fixed width. We'll use integer comparison here.
    
    n = len(e1)
    sig1 = []
    for i in range(n):
        curr = e1[i]
        nxt = e1[(i+1)%n]
        l = curr[0]**2 + curr[1]**2
        cr = curr[0]*nxt[1] - curr[1]*nxt[0]
        dt = curr[0]*nxt[0] + curr[1]*nxt[1]
        sig1.append((l, cr, dt))
        
    sig2 = []
    for i in range(n):
        curr = e2[i]
        nxt = e2[(i+1)%n]
        l = curr[0]**2 + curr[1]**2
        cr = curr[0]*nxt[1] - curr[1]*nxt[0]
        dt = curr[0]*nxt[0] + curr[1]*nxt[1]
        sig2.append((l, cr, dt))
        
    # Check cyclic match
    for i in range(n):
        match = True
        for j in range(n):
            if sig1[j] != sig2[(i+j)%n]:
                match = False
                break
        if match:
            return True
    return False

# --- Test Cases ---
test_cases = [
    ("3 4\n0 0\n0 2\n2 0\n0 2\n2 2\n2 0\n1 1", "YES"),
    ("3 4\n0 0\n0 2\n2 0\n0 2\n2 2\n2 0\n0 0", "NO"),
    ("3 3\n1 1\n2 2\n3 3\n0 10\n1 9\n2 8", "YES"),
    ("3 3\n1 1\n2 2\n3 3\n1 1\n1 2\n1 3", "NO"),
]

# --- Main Test ---
@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_rocket_safety(dut):
    # Setup
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module must have 'clk' input")
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_out) in enumerate(test_cases):
        lines = input_str.strip().split('\n')
        n, m = map(int, lines[0].split())
        
        # Parse points
        points_a = []
        for j in range(n):
            x, y = map(int, lines[1+j].split())
            points_a.append((x, y))
        points_b = []
        for j in range(m):
            x, y = map(int, lines[1+n+j].split())
            points_b.append((x, y))
            
        # Python Reference
        hull_a = convex_hull(points_a)
        hull_b = convex_hull(points_b)
        ref_res = "YES" if check_congruent(hull_a, hull_b) else "NO"
        
        # HDL Input: We assume the module has inputs for n, m and arrays of points
        # Reset signals
        dut.start.value = 0
        if has_signal(dut, 'n_a'): dut.n_a.value = n
        if has_signal(dut, 'n_b'): dut.n_b.value = m
        
        # Write points to arrays
        for idx in range(MAX_POINTS):
            if idx < n:
                x, y = points_a[idx]
                if has_signal(dut, f'arr_a_x_{idx}'):
                    getattr(dut, f'arr_a_x_{idx}').value = clamp_to_width(x, DATA_WIDTH)
                    getattr(dut, f'arr_a_y_{idx}').value = clamp_to_width(y, DATA_WIDTH)
            else:
                # Zero out unused
                if has_signal(dut, f'arr_a_x_{idx}'):
                    getattr(dut, f'arr_a_x_{idx}').value = 0
                    getattr(dut, f'arr_a_y_{idx}').value = 0
                    
        for idx in range(MAX_POINTS):
            if idx < m:
                x, y = points_b[idx]
                if has_signal(dut, f'arr_b_x_{idx}'):
                    getattr(dut, f'arr_b_x_{idx}').value = clamp_to_width(x, DATA_WIDTH)
                    getattr(dut, f'arr_b_y_{idx}').value = clamp_to_width(y, DATA_WIDTH)
            else:
                if has_signal(dut, f'arr_b_x_{idx}'):
                    getattr(dut, f'arr_b_x_{idx}').value = 0
                    getattr(dut, f'arr_b_y_{idx}').value = 0
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for result
        try:
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
                
            hdl_result_val = int(dut.result.value)
            expected_val = 1 if expected_out.strip() == "YES" else 0
            
            if hdl_result_val != expected_val:
                cocotb.log.error(f"Test {i+1} FAILED: Input {input_str[:30]}..., Expected {expected_out.strip()}, Got {'YES' if hdl_result_val else 'NO'}")
                cocotb.log.error(f"Ref check: {ref_res}")
                failed += 1
            else:
                cocotb.log.info(f"Test {i+1} PASSED: {expected_out.strip()}")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} Exception: {e}")
            failed += 1
            
        # Reset between tests
        await reset_dut(dut)

    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

    # Additional fuzzing test for valid cases
    cocotb.log.info("Running fuzzing tests...")
    for _ in range(5):
        # Generate random congruent sets
        n = 3
        base = [(0,0), (100,0), (50, 86)] # Equilateral triangle
        # Random rotation
        import random
        angle = random.uniform(0, 2*math.pi)
        rot = [(int(x*math.cos(angle) - y*math.sin(angle)), int(x*math.sin(angle) + y*math.cos(angle))) for (x,y) in base]
        # Random translation
        tx = random.randint(0, 1000)
        ty = random.randint(0, 1000)
        points_a = base
        points_b = [(x+tx, y+ty) for (x,y) in rot]
        
        # HDL Test
        dut.start.value = 0
        dut.n_a.value = n
        dut.n_b.value = n
        
        for idx in range(MAX_POINTS):
            if idx < n:
                x, y = points_a[idx]
                getattr(dut, f'arr_a_x_{idx}').value = clamp_to_width(x, DATA_WIDTH)
                getattr(dut, f'arr_a_y_{idx}').value = clamp_to_width(y, DATA_WIDTH)
            else:
                getattr(dut, f'arr_a_x_{idx}').value = 0
                getattr(dut, f'arr_a_y_{idx}').value = 0
                
        for idx in range(MAX_POINTS):
            if idx < n:
                x, y = points_b[idx]
                getattr(dut, f'arr_b_x_{idx}').value = clamp_to_width(x, DATA_WIDTH)
                getattr(dut, f'arr_b_y_{idx}').value = clamp_to_width(y, DATA_WIDTH)
            else:
                getattr(dut, f'arr_b_x_{idx}').value = 0
                getattr(dut, f'arr_b_y_{idx}').value = 0
                
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        try:
            await wait_for_done(dut)
            if int(dut.result.value) != 1:
                 raise TestFailure(f"Fuzz failed: Should be YES")
        except TestFailure as e:
             cocotb.log.error(f"Fuzz failed: {e}")
             failed += 1
             
    if failed > 0:
         raise TestFailure(f"Total {failed} tests failed")