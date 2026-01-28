import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Configuration
DATA_WIDTH = 16
ADDR_WIDTH = 3
MAX_N = 8
MAX_M = 16
MAX_ASSIGN = 4
CLK_PERIOD_NS = 10

# Helper functions
def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Algorithm implementation in Python (scaled down)
def compute_min_cost(n, edges, assignments):
    """Compute minimum cost using Floyd-Warshall and Steiner DP."""
    # Initialize distance matrix
    dist = [[math.inf] * n for _ in range(n)]
    for i in range(n):
        dist[i][i] = 0
    for u, v, c in edges:
        if c < dist[u][v]:
            dist[u][v] = c
            dist[v][u] = c
    # Floyd-Warshall
    for k in range(n):
        for i in range(n):
            for j in range(n):
                if dist[i][k] + dist[k][j] < dist[i][j]:
                    dist[i][j] = dist[i][k] + dist[k][j]
    # Build terminal set
    terminals = []
    terminal_map = {}
    for (u, v) in assignments:
        for city in [u, v]:
            if city not in terminal_map:
                terminal_map[city] = len(terminals)
                terminals.append(city)
    k = len(terminals)
    # If no terminals, return 0
    if k == 0:
        return 0
    # Steiner DP
    INF = 10**9
    dp = [[INF] * n for _ in range(1 << k)]
    for i in range(k):
        dp[1 << i][terminals[i]] = 0
    for mask in range(1, 1 << k):
        # Combine submasks
        sub = (mask - 1) & mask
        while sub > 0:
            for v in range(n):
                if dp[sub][v] < INF and dp[mask ^ sub][v] < INF:
                    dp[mask][v] = min(dp[mask][v], dp[sub][v] + dp[mask ^ sub][v])
            sub = (sub - 1) & mask
        # Relax
        for v in range(n):
            for u in range(n):
                if dp[mask][v] < INF and dist[v][u] < INF:
                    dp[mask][u] = min(dp[mask][u], dp[mask][v] + dist[v][u])
    # Get Steiner cost for mask
    steiner_cost = [INF] * (1 << k)
    for mask in range(1, 1 << k):
        steiner_cost[mask] = min(dp[mask])
    # Build forced groups (for simplicity, assume one group if no sharing, else merge)
    # We'll implement the grouping logic
    parent = list(range(len(assignments)))
    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    def union(x, y):
        rx, ry = find(x), find(y)
        if rx != ry:
            parent[ry] = rx
    for i in range(len(assignments)):
        for j in range(i+1, len(assignments)):
            a1, b1 = assignments[i]
            a2, b2 = assignments[j]
            if a1 == a2 or a1 == b2 or b1 == a2 or b1 == b2:
                union(i, j)
    groups = {}
    for i in range(len(assignments)):
        root = find(i)
        if root not in groups:
            groups[root] = []
        groups[root].append(i)
    # For each group, collect terminals and compute mask
    total_cost = 0
    for group in groups.values():
        mask = 0
        for idx in group:
            u, v = assignments[idx]
            if u in terminal_map:
                mask |= (1 << terminal_map[u])
            if v in terminal_map:
                mask |= (1 << terminal_map[v])
        if mask > 0:
            total_cost += steiner_cost[mask]
    return total_cost

# Main test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_ticket_to_ride(dut):
    """Test the ticket to ride solver."""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.edge_valid.value = 0
    dut.assignment_valid.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # Test case 1: Example from problem
        {
            'n': 10,
            'edges': [
                ('stockholm', 'amsterdam', 415),
                ('stockholm', 'helsinki', 396),
                ('oslo', 'london', 1153),
                ('oslo', 'copenhagen', 485),
                ('stockholm', 'copenhagen', 522),
                ('copenhagen', 'berlin', 354),
                ('copenhagen', 'amsterdam', 622),
                ('helsinki', 'berlin', 1107),
                ('london', 'amsterdam', 356),
                ('berlin', 'amsterdam', 575),
                ('london', 'dublin', 463),
                ('reykjavik', 'dublin', 1498),
                ('reykjavik', 'oslo', 1748),
                ('london', 'brussels', 318),
                ('brussels', 'amsterdam', 173),
            ],
            'assignments': [
                ('stockholm', 'amsterdam'),
                ('oslo', 'london'),
                ('reykjavik', 'dublin'),
                ('brussels', 'helsinki'),
            ],
            'expected': 3907
        },
        # Test case 2: Small case
        {
            'n': 2,
            'edges': [
                ('first', 'second', 10),
            ],
            'assignments': [
                ('first', 'first'),
                ('first', 'first'),
                ('second', 'first'),
                ('first', 'first'),
            ],
            'expected': 10
        }
    ]
    
    for tc in test_cases:
        # Map city names to indices (0..n-1)
        city_map = {}
        cities = []
        # In scaled-down version, we use indices directly, so we need to map
        # For this test, we'll use a fixed mapping based on input order
        # But the problem says city names are given; we need to map them
        # We'll assume the testbench knows the mapping
        # For simplicity, we'll use a precomputed mapping for the example
        if tc['n'] == 10:
            # Mapping for example case
            city_map = {
                'stockholm': 0, 'amsterdam': 1, 'london': 2, 'berlin': 3,
                'copenhagen': 4, 'oslo': 5, 'helsinki': 6, 'dublin': 7,
                'reykjavik': 8, 'brussels': 9
            }
        else:
            # For small case, assign indices by order
            city_list = []
            for u, v, c in tc['edges']:
                if u not in city_list:
                    city_list.append(u)
                if v not in city_list:
                    city_list.append(v)
            for i, city in enumerate(city_list):
                city_map[city] = i
        
        # Convert to numeric values
        n = tc['n']
        m = len(tc['edges'])
        edges = []
        for (u, v, c) in tc['edges']:
            edges.append((city_map[u], city_map[v], c))
        assignments = []
        for (u, v) in tc['assignments']:
            assignments.append((city_map[u], city_map[v]))
        
        # Compute expected
        expected = compute_min_cost(n, edges, assignments)
        
        dut._log.info(f"Testing case: n={n}, m={m}, expected={expected}")
        
        # Load n and m
        dut.n.value = n
        dut.m.value = m
        await RisingEdge(dut.clk)
        
        # Load edges
        for (u, v, c) in edges:
            dut.edge_u.value = u
            dut.edge_v.value = v
            dut.edge_cost.value = c
            dut.edge_valid.value = 1
            await RisingEdge(dut.clk)
            dut.edge_valid.value = 0
            await RisingEdge(dut.clk)
        
        # Load assignments
        for (u, v) in assignments:
            dut.assign_u.value = u
            dut.assign_v.value = v
            dut.assignment_valid.value = 1
            await RisingEdge(dut.clk)
            dut.assignment_valid.value = 0
            await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        cycles = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > 1000:
                raise TestFailure("Timeout waiting for done")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        
        dut._log.info(f"Test passed: result={result}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
