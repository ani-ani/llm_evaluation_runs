import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Max sizes for scaled problem
MAX_N = 16
MAX_C = 15
MAX_EDGES = 64
DATA_WIDTH = 16
IDX_WIDTH = 4
MAX_WEIGHT = (1 << DATA_WIDTH) - 1
INF = MAX_WEIGHT

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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=20000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python reference for verification
def compute_min_trucks(N, C, clients, edges, max_n=MAX_N, max_c=MAX_C):
    # Floyd-Warshall
    dist = [[INF] * N for _ in range(N)]
    for i in range(N):
        dist[i][i] = 0
    
    for u, v, w in edges:
        if u < N and v < N:
            dist[u][v] = min(dist[u][v], w)
    
    for k in range(N):
        for i in range(N):
            if dist[i][k] == INF: continue
            for j in range(N):
                if dist[k][j] == INF: continue
                if dist[i][k] + dist[k][j] < dist[i][j]:
                    dist[i][j] = dist[i][k] + dist[k][j]
    
    # Check reachability
    for c in clients:
        if dist[0][c] == INF:
            return -1 # Unreachable
            
    # Build DAG for clients
    # Map client index to its node index
    client_nodes = clients
    dist_to = [dist[0][c] for c in client_nodes]
    
    # Adjacency for bipartite matching
    # Left: clients 0..C-1, Right: clients 0..C-1
    adj = [[False] * C for _ in range(C)]
    
    for i in range(C):
        for j in range(C):
            if i == j: continue
            u = client_nodes[i]
            v = client_nodes[j]
            d_u = dist_to[i]
            d_v = dist_to[j]
            d_uv = dist[u][v]
            if d_uv == INF: continue
            # Check if path via u is shortest to v
            # If d_u + d_uv == d_v, it means the shortest path to v goes through u (or a node with same distance)
            if d_u + d_uv == d_v:
                adj[i][j] = True
    
    # Max Bipartite Matching
    match_r = [-1] * C
    def dfs(u, seen):
        for v in range(C):
            if adj[u][v] and not seen[v]:
                seen[v] = True
                if match_r[v] == -1 or dfs(match_r[v], seen):
                    match_r[v] = u
                    return True
        return False
    
    match_count = 0
    for u in range(C):
        seen = [False] * C
        if dfs(u, seen):
            match_count += 1
            
    return C - match_count

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_min_vehicles(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from problem statement (scaled down)
    # Scale: N=4 -> 4, M=5 -> 5, C=3 -> 3
    
    test_cases = [
        {
            'N': 4, 'C': 3, 'clients': [1, 2, 3],
            'edges': [(0,1,1), (0,3,1), (0,2,2), (1,2,1), (3,2,1)],
            'expected': 2
        },
        {
            'N': 4, 'C': 3, 'clients': [1, 2, 3],
            'edges': [(0,1,1), (0,3,1), (0,2,1), (1,2,1), (3,2,1)],
            'expected': 3
        },
        {
            'N': 8, 'C': 5, 'clients': [1, 3, 4, 6, 7],
            'edges': [
                (0,1,5), (0,4,1), (0,2,2), (0,6,6),
                (2,3,1), (2,6,3), (3,5,7), (4,1,5),
                (5,7,3), (6,5,6), (4,6,4)
            ],
            'expected': 3
        }
    ]
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: N={tc['N']}, C={tc['C']}")
        
        # Set inputs
        dut.start.value = 1
        dut.N.value = tc['N']
        dut.C.value = tc['C']
        
        # Set clients (indices 0..14)
        for idx in range(MAX_C):
            attr = f'client_idx_{idx}'
            if idx < len(tc['clients']):
                getattr(dut, attr).value = tc['clients'][idx]
            else:
                getattr(dut, attr).value = 0
        
        # Set edges
        valid_edges = len(tc['edges'])
        dut.valid_edges.value = valid_edges
        
        for idx in range(MAX_EDGES):
            u_attr = f'edge_u_{idx}'
            v_attr = f'edge_v_{idx}'
            w_attr = f'edge_w_{idx}'
            
            if idx < valid_edges:
                u, v, w = tc['edges'][idx]
                getattr(dut, u_attr).value = u
                getattr(dut, v_attr).value = v
                getattr(dut, w_attr).value = w
            else:
                getattr(dut, u_attr).value = 0
                getattr(dut, v_attr).value = 0
                getattr(dut, w_attr).value = 0
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        result = int(dut.result.value)
        expected = tc['expected']
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        if has_signal(dut, 'error') and int(dut.error.value) == 1:
            raise TestFailure(f"Test {i+1}: Error signal asserted")
            
        cocotb.log.info(f"Test {i+1} Passed: Result {result}")
