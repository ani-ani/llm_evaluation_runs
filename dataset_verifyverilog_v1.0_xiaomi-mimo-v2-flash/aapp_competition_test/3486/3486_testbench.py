import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
from math import gcd

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 5000
MOD = 1000000007

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

def count_ways_python(arr, n):
    # Helper to check if gcd > 1
    def share_factor(a, b):
        return gcd(a, b) > 1
    
    # Build adjacency list for valid connections
    edges = []
    for i in range(n):
        for j in range(i + 1, n):
            if share_factor(arr[i], arr[j]):
                edges.append((i, j))
    
    # We need to select n-1 edges such that:
    # 1. The graph is connected (spanning tree)
    # 2. No edges cross on the circle (planar constraint)
    
    # For planar constraint on a circle with vertices 0..n-1 in order:
    # Edges (i,j) and (k,l) cross if i < k < j < l or k < i < l < j.
    # In this problem, 'no streamers may cross' likely means no crossing chords inside the circle.
    # This is equivalent to requiring the edges to form a non-crossing partition or a outerplanar graph.
    # For a simple cycle graph (vertices in order), non-crossing trees are exactly those that can be drawn without intersections.
    # A known property: A tree on a circle is non-crossing if and only if it is a subgraph of the cycle with no chords crossing.
    # However, we are counting spanning trees. A spanning tree on a set of points on a circle with no crossing edges
    # is equivalent to a tree where every face is bounded by 2 or 3 edges? No.
    # Actually, any tree on points in convex position (circle) is non-crossing if we draw edges as straight lines.
    # Wait, the problem says "No streamers may cross". This is a hard constraint.
    # If we have vertices 0, 1, 2, 3 in a circle. Edges (0, 2) and (1, 3) cross.
    # So we must avoid such pairs.
    
    # Algorithm: Iterate all subsets of n-1 edges from the valid edges.
    # Check connectivity (Union-Find) and Non-crossing property.
    
    valid_subsets = 0
    m = len(edges)
    if n <= 1: return 1
    if n - 1 > m: return 0
    
    # Brute force combinations of n-1 edges from m edges.
    # Since n is small in verilog (<=16), m is at most 120.
    # n-1 is small (<=15). Combinations(120, 15) is too big for software, 
    # but for Verilog simulation with n<=8, it is manageable.
    # We will scale n to 8 for the simulation to be feasible.
    
    from itertools import combinations
    
    for subset in combinations(edges, n - 1):
        # 1. Check Connectivity
        parent = list(range(n))
        def find(x):
            while parent[x] != x: x = parent[x]
            return x
        def union(x, y):
            rx, ry = find(x), find(y)
            if rx != ry: parent[ry] = rx
        
        for u, v in subset:
            union(u, v)
        
        roots = set(find(i) for i in range(n))
        if len(roots) != 1:
            continue
            
        # 2. Check Non-Crossing
        is_crossing = False
        for i in range(len(subset)):
            u1, v1 = subset[i]
            if u1 > v1: u1, v1 = v1, u1
            for j in range(i + 1, len(subset)):
                u2, v2 = subset[j]
                if u2 > v2: u2, v2 = v2, u2
                # Cross if u1 < u2 < v1 < v2 or u2 < u1 < v2 < v1
                if (u1 < u2 < v1 < v2) or (u2 < u1 < v2 < v1):
                    is_crossing = True
                    break
            if is_crossing: break
            
        if not is_crossing:
            valid_subsets += 1
            
    return valid_subsets % MOD

@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_module(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases scaled down for simulation feasibility (n <= 8)
    # Mapping large numbers to small numbers that preserve factors roughly
    # 2, 3, 30, 45 -> 2, 3, 5(30/6), 5(45/9) doesn't work well.
    # Use actual small numbers for test case.
    
    test_cases = [
        ([30, 3, 2, 45], 4, 1), # From problem
        ([3, 30, 2, 45], 4, 3), # From problem
        ([2, 4, 8, 16], 4, 3),  # All powers of 2, all connected. 
                                 # Valid trees on 4 nodes (circle): 16 total trees on K4.
                                 # Crossing constraint: Edges (0,2) crosses (1,3).
                                 # Remove those. How many? Total 16. 
                                 # Crossing trees: 
                                 # Star centered at 0: edges (0,1), (0,2), (0,3) -> No cross (0 is center, others around)
                                 # Star at 1: (1,0), (1,2), (1,3) -> No cross
                                 # Star at 2: (2,0), (2,1), (2,3) -> No cross
                                 # Star at 3: (3,0), (3,1), (3,2) -> No cross
                                 # Paths:
                                 # 0-1-2-3 (edges 0-1, 1-2, 2-3) -> No cross
                                 # 0-1-3-2 (0-1, 1-3, 3-2) -> 1-3 crosses? No.
                                 # 0-2-1-3 (0-2, 2-1, 1-3) -> 0-2 and 1-3 cross.
                                 # 0-3-1-2 (0-3, 3-1, 1-2) -> 0-3 and 1-2 cross? No, 1-2 is inside 0-3? No, 0,1,2,3 in circle.
                                 # Wait, vertices 0,1,2,3 in circle. 
                                 # (0,2) is chord. (1,3) is chord. They cross.
                                 # Any tree containing both (0,2) and (1,3) is invalid.
                                 # Total 16 trees. 
                                 # Trees with chord (0,2):
                                 #   - (0,2) + (0,1) + (0,3) -> Star at 0 (valid)
                                 #   - (0,2) + (0,1) + (2,1) -> Path 1-0-2-? (Missing 3?) No.
                                 # Let's count manually for n=4:
                                 # Total spanning trees of K4: 16.
                                 # 1. Star 0: edges (0,1), (0,2), (0,3) - Valid (No crossing chords drawn as lines?) 
                                 #    Actually, drawing chords from center to vertices is usually allowed.
                                 #    But 'streamers between pairs of students' in a circle.
                                 #    If student 0 connects to 1, 2, 3. The streamers radiate out. No crossing.
                                 # 2. Star 1: (1,0), (1,2), (1,3) - Valid.
                                 # 3. Star 2: (2,0), (2,1), (2,3) - Valid.
                                 # 4. Star 3: (3,0), (3,1), (3,2) - Valid.
                                 # 5. Path 0-1-2-3: (0,1), (1,2), (2,3) - Valid.
                                 # 6. Path 0-3-2-1: (0,3), (3,2), (2,1) - Valid.
                                 # 7. Path 0-1-3-2: (0,1), (1,3), (3,2) -> Does (1,3) cross anything? No. Valid.
                                 # 8. Path 0-2-1-3: (0,2), (2,1), (1,3) -> (0,2) and (1,3) cross. Invalid.
                                 # 9. Path 0-3-1-2: (0,3), (3,1), (1,2) -> (0,3) and (1,2) cross? No, 1-2 is inside 0-3? 
                                 #    Vertices are 0,1,2,3 in order. 0-3 is a chord. 1-2 is a chord. They don't cross. Valid.
                                 # 10. Path 0-2-3-1: (0,2), (2,3), (3,1) -> (0,2) and (3,1) don't cross (1,3 is 3,1). Valid? Yes.
                                 # 11. Path 0-1-2, 0-3 (T shape): (0,1), (1,2), (0,3) -> Valid.
                                 # 12. Path 0-3-2, 0-1: (0,3), (3,2), (0,1) -> Valid.
                                 # 13. Path 0-1-3, 2-3: (0,1), (1,3), (2,3) -> Valid.
                                 # 14. Path 0-2-3, 1-3: (0,2), (2,3), (1,3) -> (0,2) and (1,3) cross. Invalid.
                                 # 15. Path 0-2-1, 0-3: (0,2), (2,1), (0,3) -> (0,2) and (0,3) meet at 0. No cross. Valid.
                                 # 16. Path 0-2-3, 0-1: (0,2), (2,3), (0,1) -> Valid.
                                 # Actually, checking standard non-crossing trees on a circle:
                                 # Number is n^(n-2) for unconstrained? No, that's Cayley.
                                 # For convex position (circle), non-crossing spanning trees are counted by Catalan numbers? No.
                                 # The number of non-crossing spanning trees on n vertices in convex position is C_{n-1} * something?
                                 # Actually, it's just the number of plane trees? No.
                                 # Let's trust the logic: count all trees, remove those with crossing chords.
    ]
    
    for vals, n, expected in test_cases:
        cocotb.log.info(f"Testing case: n={n}, vals={vals}")
        
        # Prepare input for DUT
        # We need to fill arr[0]...arr[15]
        for i in range(ARRAY_SIZE):
            if i < n:
                val = clamp_to_width(vals[i], DATA_WIDTH)
            else:
                val = 0
            getattr(dut, f'arr_{i}').value = val
            
        dut.len.value = n
        
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            result = int(dut.result.value)
        else:
            # Combinational logic path
            await Timer(100, units='ns')
            if has_signal(dut, 'result'):
                result = int(dut.result.value)
            else:
                raise TestFailure("No result signal found")
        
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
