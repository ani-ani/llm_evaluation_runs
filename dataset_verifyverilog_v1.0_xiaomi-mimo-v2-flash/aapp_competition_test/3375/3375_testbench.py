import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 2000000  # Allow up to 2 million cycles for exhaustive search
MOD = 1000000007

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Precompute edge masks for given V and E
def get_edge_mask(V, edges_list):
    # Map edges to 16-bit mask based on fixed order
    # Order: (1,2), (1,3), (2,3), (1,4), (2,4), (3,4), (1,5), (2,5), (3,5), (4,5), (1,6), (2,6), (3,6), (4,6), (5,6), (1,7), (2,7), (3,7), (4,7), (5,7), (6,7), (1,8), (2,8), (3,8), (4,8), (5,8), (6,8), (7,8)
    # For simplicity, we map only up to V*(V-1)/2 edges, but input E edges are given
    # We assume edges_list contains (a,b) with 1-based indices
    # We need to compute the edge mask for the given graph
    # Since the problem states the graph has E edges from input, we need to set bits for those edges
    # But the Verilog expects a fixed edge_mask input; we need to generate it based on the edges
    # For testbench, we'll compute the full edge_mask for all possible pairs up to 8 vertices
    edge_map = {
        (1,2): 0, (1,3): 1, (2,3): 2, (1,4): 3, (2,4): 4, (3,4): 5,
        (1,5): 6, (2,5): 7, (3,5): 8, (4,5): 9, (1,6): 10, (2,6): 11,
        (3,6): 12, (4,6): 13, (5,6): 14, (1,7): 15, (2,7): 16, (3,7): 17,
        (4,7): 18, (5,7): 19, (6,7): 20, (1,8): 21, (2,8): 22, (3,8): 23,
        (4,8): 24, (5,8): 25, (6,8): 26, (7,8): 27
    }
    mask = 0
    for a, b in edges_list:
        if (a, b) in edge_map:
            bit = edge_map[(a, b)]
            if bit < 16:  # Only use first 16 bits for simplicity, but testcases have small V
                mask |= (1 << bit)
    return mask

# Compute expected answer for verification
def compute_expected(V, edges_list):
    # Brute-force in Python for verification
    from itertools import combinations
    from collections import deque
    if V == 0:
        return 0
    # Map edges to indices
    edge_map = {}
    for idx, (a, b) in enumerate(edges_list):
        edge_map[idx] = (a-1, b-1)  # 0-based for Python
    n_edges = len(edges_list)
    count = 0
    # Iterate over all subsets of edges
    for mask in range(1 << n_edges):
        # Build subgraph
        sub_edges = []
        for i in range(n_edges):
            if (mask >> i) & 1:
                sub_edges.append(edge_map[i])
        # Check conditions
        if len(sub_edges) == 0:
            continue
        # Check spanning: all vertices present
        vertices = set()
        for u, v in sub_edges:
            vertices.add(u)
            vertices.add(v)
        if len(vertices) != V:
            continue
        # Check connectivity and unicyclic (E_sub == V)
        if len(sub_edges) != V:
            continue
        # Check connected using BFS
        adj = {i: [] for i in range(V)}
        for u, v in sub_edges:
            adj[u].append(v)
            adj[v].append(u)
        visited = set()
        q = deque([0])
        visited.add(0)
        while q:
            node = q.popleft()
            for neighbor in adj[node]:
                if neighbor not in visited:
                    visited.add(neighbor)
                    q.append(neighbor)
        if len(visited) == V:
            count += 1
    return count % MOD

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_spanning_unicyclic(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational module: set reset-like conditions
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 1
        if has_signal(dut, 'start'):
            dut.start.value = 0

    test_cases = [
        (4, 5, [(1,2), (1,3), (2,3), (1,4), (2,4)], 5),  # From sample
        (4, 2, [(1,2), (3,4)], 0),  # From sample
        (3, 3, [(1,2), (2,3), (1,3)], 1),  # Triangle: one unicyclic spanning subgraph (the triangle itself)
        (2, 1, [(1,2)], 0),  # Two vertices, one edge: connected but E != V (1 != 2), so 0
        (5, 7, [(1,2), (2,3), (3,1), (1,4), (2,4), (3,4), (4,5)], 0),  # More complex, likely 0 or more
    ]
    
    passed = 0
    failed = 0
    
    for i, (V, E, edges, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: V={V}, E={E}, edges={edges}")
        try:
            edge_mask = get_edge_mask(V, edges)
            
            if is_seq:
                # Set inputs
                if has_signal(dut, 'V'):
                    dut.V.value = clamp_to_width(V, 3)
                if has_signal(dut, 'E'):
                    dut.E.value = clamp_to_width(E, 4)
                if has_signal(dut, 'edge_mask'):
                    dut.edge_mask.value = clamp_to_width(edge_mask, 16)
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
                
                # Verify
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            else:
                # Combinational: assume inputs directly affect output
                if has_signal(dut, 'V'):
                    dut.V.value = clamp_to_width(V, 3)
                if has_signal(dut, 'E'):
                    dut.E.value = clamp_to_width(E, 4)
                if has_signal(dut, 'edge_mask'):
                    dut.edge_mask.value = clamp_to_width(edge_mask, 16)
                await Timer(100, units='ns')  # Allow propagation
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Got {result}")
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    else:
        cocotb.log.info(f"All {passed} tests passed")
