import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import heapq

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# TEST FUNCTION
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_min_trucks(dut):
    '''Test the min_trucks module with scaled-down inputs.'''
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input string, expected answer)
    test_cases = [
        ("""4 5 3
1 2 3
0 1 1
0 3 1
0 2 2
1 2 1
3 2 1""", 2),
        ("""4 5 3
1 2 3
0 1 1
0 3 1
0 2 1
1 2 1
3 2 1""", 3),
        ("""8 11 5
1 3 4 6 7
0 1 5
0 4 1
0 2 2
0 6 6
2 3 1
2 6 3
3 5 7
4 1 5
5 7 3
6 5 6
4 6 4""", 3)
    ]
    
    for idx, (input_str, expected) in enumerate(test_cases):
        dut._log.info(f'Test {idx}: Processing...')
        
        # Parse input
        lines = input_str.strip().split('\n')
        first = lines[0].split()
        N = int(first[0]); M = int(first[1]); C = int(first[2])
        clients = list(map(int, lines[1].split()))
        edges = []
        for i in range(2, 2+M):
            u, v, w = map(int, lines[i].split())
            edges.append((u, v, w))
        
        # Build adjacency list
        adj = [[] for _ in range(N)]
        for u, v, w in edges:
            adj[u].append((v, w))
        
        # Compute shortest distances from warehouse (0)
        dist0 = [float('inf')] * N
        dist0[0] = 0
        pq = [(0, 0)]
        while pq:
            d, u = heapq.heappop(pq)
            if d != dist0[u]:
                continue
            for v, w in adj[u]:
                if dist0[u] + w < dist0[v]:
                    dist0[v] = dist0[u] + w
                    heapq.heappush(pq, (dist0[v], v))
        
        # Compute distances between clients
        client_dist = [[float('inf')] * C for _ in range(C)]
        for i in range(C):
            src = clients[i]
            dist_src = [float('inf')] * N
            dist_src[src] = 0
            pq = [(0, src)]
            while pq:
                d, u = heapq.heappop(pq)
                if d != dist_src[u]:
                    continue
                for v, w in adj[u]:
                    if dist_src[u] + w < dist_src[v]:
                        dist_src[v] = dist_src[u] + w
                        heapq.heappush(pq, (dist_src[v], v))
            for j in range(C):
                dst = clients[j]
                client_dist[i][j] = dist_src[dst]
        
        # Build reach matrix
        reach_matrix = [[0]*C for _ in range(C)]
        for i in range(C):
            for j in range(C):
                if i != j:
                    if dist0[clients[i]] + client_dist[i][j] == dist0[clients[j]]:
                        reach_matrix[i][j] = 1
        
        # Pack reach into 64-bit integer (8x8 matrix)
        reach_packed = 0
        for i in range(8):
            for j in range(8):
                if i < C and j < C:
                    if reach_matrix[i][j]:
                        reach_packed |= 1 << (i*8 + j)
        
        # Drive DUT
        dut.C.value = C
        dut.reach.value = reach_packed
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        timeout = 20000  # cycles
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f'Test {idx}: Timeout waiting for done')
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f'Test {idx}: Result is undefined')
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f'Test {idx}: expected {expected}, got {result}')
        
        dut._log.info(f'Test {idx}: PASS (result={result})')
        
        # Wait a few cycles before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)