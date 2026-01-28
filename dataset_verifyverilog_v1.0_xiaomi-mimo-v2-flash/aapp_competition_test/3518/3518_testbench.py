import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MAX_NODES = 16
MAX_EDGES = 32
DATA_WIDTH = 16
ADDR_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 3000

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'edge_valid'): dut.edge_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Python reference implementation for verification
def min_weight_perfect_matching(n, edges):
    # n: number of nodes (0..n-1)
    # edges: list of (u, v, w)
    # Returns min weight or None
    
    INF = 10**9
    # Adjacency matrix for quick lookup
    adj = [[INF]*n for _ in range(n)]
    for u, v, w in edges:
        adj[u][v] = w
        adj[v][u] = w
    
    if n % 2 != 0:
        return None

    dp = [INF] * (1 << n)
    dp[0] = 0

    for mask in range(1 << n):
        if dp[mask] == INF:
            continue
        # Find first unset bit (or just iterate all pairs)
        # Standard DP: match the lowest free node
        first = -1
        for i in range(n):
            if not (mask & (1 << i)):
                first = i
                break
        
        if first == -1:
            continue # All matched

        # Try to match 'first' with any other free node
        for j in range(first + 1, n):
            if not (mask & (1 << j)):
                if adj[first][j] != INF:
                    new_mask = mask | (1 << first) | (1 << j)
                    dp[new_mask] = min(dp[new_mask], dp[mask] + adj[first][j])

    final_mask = (1 << n) - 1
    if dp[final_mask] >= INF:
        return None
    return dp[final_mask]

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_min_matching(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    await reset_dut(dut)
    
    # Test Case 1: Impossible (odd number of nodes)
    # Input: 3 nodes, edges: 0-1 (10), 1-2 (20)
    # Expected: Impossible
    
    cocotb.log.info("Test Case 1: Impossible (odd nodes)")
    n = 3
    edges = [(0, 1, 10), (1, 2, 20)]
    
    if has_signal(dut, 'num_nodes'):
        dut.num_nodes.value = n
        await RisingEdge(dut.clk)
    
    # Send edges
    for u, v, w in edges:
        if has_signal(dut, 'edge_u'):
            dut.edge_u.value = u
            dut.edge_v.value = v
            dut.edge_weight.value = w
            dut.edge_valid.value = 1
            await RisingEdge(dut.clk)
    
    dut.edge_valid.value = 0
    await RisingEdge(dut.clk)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    # Expect 0xFFFFFF or similar flag (assuming 24-bit)
    # Let's assume 0xFFFFFF is the impossible flag based on prompt constraints
    if result != 0xFFFFFF:
         raise TestFailure(f"Case 1: Expected impossible (0xFFFFFF), got {result}")
    
    # Test Case 2: Possible
    # 4 nodes (0,1,2,3)
    # Edges: 0-1 (5), 0-2 (10), 1-2 (5), 2-3 (5), 0-3 (20)
    # Optimal: (0-1, 2-3) = 5 + 5 = 10
    
    await reset_dut(dut)
    cocotb.log.info("Test Case 2: Possible (4 nodes)")
    
    n = 4
    edges = [(0, 1, 5), (0, 2, 10), (1, 2, 5), (2, 3, 5), (0, 3, 20)]
    
    # Python ref check
    expected = min_weight_perfect_matching(n, edges)
    cocotb.log.info(f"Python ref expects: {expected}")
    
    if has_signal(dut, 'num_nodes'):
        dut.num_nodes.value = n
        await RisingEdge(dut.clk)
        
    for u, v, w in edges:
        if has_signal(dut, 'edge_u'):
            dut.edge_u.value = u
            dut.edge_v.value = v
            dut.edge_weight.value = w
            dut.edge_valid.value = 1
            await RisingEdge(dut.clk)
            
    dut.edge_valid.value = 0
    await RisingEdge(dut.clk)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    if expected is None:
        if result != 0xFFFFFF:
            raise TestFailure(f"Case 2: Expected impossible, got {result}")
    else:
        if result != expected:
            raise TestFailure(f"Case 2: Expected {expected}, got {result}")

    # Test Case 3: Given example (scaled)
    # Original: 6 nodes, 7 edges. Result 900.
    # We scale nodes to 0-5. Weights scaled down if needed, but 16-bit handles original.
    # Example input: 
    # 5 6 600 -> (4, 5, 600)
    # 2 5 200 -> (1, 4, 200) -> Note: IDs in problem are 1-based.
    # Let's use exact IDs 0-5 for the example
    # Mapping: 1->0, 2->1, 3->2, 4->3, 5->4, 6->5
    # Edges:
    # 5 6 600 -> 4 5 600
    # 2 5 200 -> 1 4 200
    # 3 5 400 -> 2 4 400
    # 6 3 500 -> 5 2 500
    # 1 4 300 -> 0 3 300
    # 3 2 400 -> 2 1 400
    # 6 2 200 -> 5 1 200
    
    await reset_dut(dut)
    cocotb.log.info("Test Case 3: Example 2 (6 nodes)")
    
    n = 6
    edges = [
        (4, 5, 600),
        (1, 4, 200),
        (2, 4, 400),
        (5, 2, 500),
        (0, 3, 300),
        (2, 1, 400),
        (5, 1, 200)
    ]
    
    expected = min_weight_perfect_matching(n, edges)
    cocotb.log.info(f"Python ref expects: {expected}")
    
    if has_signal(dut, 'num_nodes'):
        dut.num_nodes.value = n
        await RisingEdge(dut.clk)
        
    for u, v, w in edges:
        if has_signal(dut, 'edge_u'):
            dut.edge_u.value = u
            dut.edge_v.value = v
            dut.edge_weight.value = w
            dut.edge_valid.value = 1
            await RisingEdge(dut.clk)
            
    dut.edge_valid.value = 0
    await RisingEdge(dut.clk)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    if expected is None:
        if result != 0xFFFFFF:
            raise TestFailure(f"Case 3: Expected impossible, got {result}")
    else:
        if result != expected:
            raise TestFailure(f"Case 3: Expected {expected}, got {result}")
