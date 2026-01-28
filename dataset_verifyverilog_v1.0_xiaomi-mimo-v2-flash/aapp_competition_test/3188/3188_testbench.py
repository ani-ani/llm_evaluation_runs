import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# --- Helpers ---
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

# --- Testbench Constants ---
CLK_NS = 10
MAX_CYCLES = 2000

# --- Helper: Write Coordinates ---
async def write_coords(dut, coords):
    """
    coords: list of tuples [(x,y,z), ...]
    Writes to dut.coord_x[i], dut.coord_y[i], dut.coord_z[i]
    """
    for i, (x, y, z) in enumerate(coords):
        # Clamp to 16 bits signed range (-32768 to 32767)
        # Since inputs are large, we just cast to int (sim handles X/Z)
        # But for simulation stability, let's use 16-bit wrap
        x_w = x & 0xFFFF
        y_w = y & 0xFFFF
        z_w = z & 0xFFFF
        
        getattr(dut, f'coord_x_{i}').value = x_w
        getattr(dut, f'coord_y_{i}').value = y_w
        getattr(dut, f'coord_z_{i}').value = z_w

# --- Helper: Python Reference ---
def calculate_mst_python(coords):
    n = len(coords)
    if n <= 1:
        return 0
    
    # Generate edges
    edges = []
    for i in range(n):
        for j in range(i + 1, n):
            xi, yi, zi = coords[i]
            xj, yj, zj = coords[j]
            cost = min(abs(xi - xj), abs(yi - yj), abs(zi - zj))
            edges.append((cost, i, j))
    
    # Sort edges
    edges.sort()
    
    # Kruskal's Union-Find
    parent = list(range(n))
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    
    def union(i, j):
        root_i = find(i)
        root_j = find(j)
        if root_i != root_j:
            parent[root_i] = root_j
            return True
        return False
    
    mst_cost = 0
    edges_count = 0
    for cost, u, v in edges:
        if union(u, v):
            mst_cost += cost
            edges_count += 1
            if edges_count == n - 1:
                break
                
    return mst_cost

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_mst(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases (Scaled down to fit N <= 8)
    # Case 1: N=2 (Simple distance)
    test_cases = [
        {
            "n": 2,
            "coords": [(1, 5, 10), (7, 8, 2)],
            "expected": 3  # min(|1-7|, |5-8|, |10-2|) = min(6,3,8) = 3
        },
        {
            "n": 3,
            "coords": [(-1, -1, -1), (5, 5, 5), (10, 10, 10)],
            "expected": 11 # Edges: (0,1)=6, (1,2)=5, (0,2)=11. MST: 6+5=11
        },
        {
            "n": 4,
            "coords": [(0,0,0), (10,0,0), (0,10,0), (0,0,10)],
            "expected": 10 # 3 edges of cost 10
        }
    ]

    passed = 0
    failed = 0

    for tc in test_cases:
        n = tc['n']
        coords = tc['coords']
        expected = tc['expected']
        
        # Verify expected with python reference
        py_calc = calculate_mst_python(coords)
        if py_calc != expected:
             cocotb.log.error(f"Internal Test Error: Python calc {py_calc} != Expected {expected}")
             raise TestFailure("Test case definition error")

        cocotb.log.info(f"Running test: N={n}, Expected={expected}")
        
        # Set Inputs
        dut.n.value = n
        await write_coords(dut, coords)
        
        # Pulse Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for Done
        done = False
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            cocotb.log.error(f"Timeout waiting for done signal")
            failed += 1
            continue
            
        # Check Result
        if not is_value_defined(dut.result.value):
             cocotb.log.error(f"Result signal undefined")
             failed += 1
             continue
             
        result = int(dut.result.value)
        if result != expected:
            cocotb.log.error(f"FAIL: N={n}. Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"PASS: N={n}. Result {result}")
            passed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
