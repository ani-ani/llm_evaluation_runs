import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# --- Helper Functions ---
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def clamp_to_width(v, bits):
    if v >= 0:
        return min((1 << bits) - 1, v)
    else:
        # Handle signed clamping if needed, but inputs are positive here usually
        return max(-(1 << (bits-1)), v)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# --- Geometry Helpers (Python side) ---
def cross_product(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

def is_inside_convex(onion, polygon):
    # Polygon is list of (x,y) in clockwise order.
    # If onion is strictly inside, cross product with all edges must have same sign.
    # For clockwise order, cross product (edge, point) should be < 0 for inside (assuming standard Z-up).
    # Let's use consistent logic: check if point is to the right of all edges.
    n = len(polygon)
    if n < 3: return False
    
    # Determine sign of the first edge
    cp0 = cross_product(polygon[0], polygon[1], onion)
    if cp0 == 0: return False # On edge is not strictly inside
    
    # For clockwise, inside usually means cp < 0 (right side)
    # If cp0 > 0, we are on the 'outside' side. 
    # Actually, let's just check all have the same sign (non-zero).
    sign = 1 if cp0 > 0 else -1
    
    for i in range(n):
        p1 = polygon[i]
        p2 = polygon[(i + 1) % n]
        cp = cross_product(p1, p2, onion)
        
        # Strictly inside: cp != 0 and consistent sign
        if cp == 0: return False
        if (cp > 0 and sign < 0) or (cp < 0 and sign > 0):
            return False
    return True

# --- Testbench ---
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_onion_thief(dut):
    # Configuration
    CLK_NS = 10
    DATA_WIDTH = 16
    MAX_M = 16
    MAX_N = 16
    
    # Start Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test Case 1: Small M, N
    # Input 1 from prompt scaled down to fit M=5, N=3 -> fits in 16
    onions = [(1, 1), (2, 2), (1, 3)]
    posts = [(0, 0), (0, 3), (1, 4), (3, 3), (3, 0)]
    K = 3
    
    # Calculate expected result in Python
    max_onions = 0
    # Iterate combinations of K posts
    from itertools import combinations
    for subset_indices in combinations(range(len(posts)), K):
        poly = [posts[i] for i in subset_indices]
        # The subset of vertices of a convex polygon might not be in order.
        # We need to sort them angularly or by original index to form convex hull.
        # Since original posts are in clockwise order, we sort by index.
        poly_sorted = sorted(poly, key=lambda p: posts.index(p))
        
        count = 0
        for o in onions:
            if is_inside_convex(o, poly_sorted):
                count += 1
        if count > max_onions:
            max_onions = count
            
    cocotb.log.info(f"Expected Result: {max_onions}")
    
    # Load Data into DUT
    # We assume the DUT has configuration registers or a loading state.
    # For this simulation, we'll drive inputs assuming a loading sequence.
    # The spec mentions `config_valid`, `onion_x/y`, `post_x/y`.
    # We will simulate writing to a memory interface if exposed, or toggle config_valid.
    
    # Let's assume a simple load sequence:
    # 1. Write N, M, K
    # 2. Write N pairs of onions
    # 3. Write M pairs of posts
    
    if has_signal(dut, 'cfg_len_n'):
        dut.cfg_len_n.value = len(onions)
        dut.cfg_len_m.value = len(posts)
        dut.cfg_k.value = K
        await RisingEdge(dut.clk)
        
        for x, y in onions:
            dut.onion_x.value = clamp_to_width(x, DATA_WIDTH)
            dut.onion_y.value = clamp_to_width(y, DATA_WIDTH)
            dut.config_valid.value = 1
            await RisingEdge(dut.clk)
        
        for x, y in posts:
            dut.post_x.value = clamp_to_width(x, DATA_WIDTH)
            dut.post_y.value = clamp_to_width(y, DATA_WIDTH)
            dut.config_valid.value = 1
            await RisingEdge(dut.clk)
            
        dut.config_valid.value = 0
    else:
        # Fallback for simpler interface: assuming inputs are directly hooked up
        # Just trigger start if inputs are already set or load via a different mechanism
        cocotb.log.warning("Assuming data pre-loaded or direct connection for simplicity")
    
    # Start Computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Check Result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result signal is undefined")
        
    result = int(dut.result.value)
    cocotb.log.info(f"DUT Result: {result}")
    
    if result != max_onions:
        raise TestFailure(f"Mismatch. Expected {max_onions}, got {result}")
