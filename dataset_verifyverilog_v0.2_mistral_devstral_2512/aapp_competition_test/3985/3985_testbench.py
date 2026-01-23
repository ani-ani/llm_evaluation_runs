import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def factorize(n):
    """Return list of prime factors for n (up to 255)"""
    factors = []
    d = 2
    while d * d <= n:
        while n % d == 0:
            factors.append(d)
            n //= d
        d += 1
    if n > 1:
        factors.append(n)
    return factors

def solve_max_ops(n, m, a, pairs):
    """Python reference for max operations using bipartite matching"""
    # Build graph of prime factors
    left_nodes = []  # (prime, position) for odd positions
    right_nodes = []  # (prime, position) for even positions
    
    for i in range(n):
        pos = i + 1
        factors = factorize(a[i])
        for f in factors:
            if pos % 2 == 1:  # odd position -> left
                left_nodes.append((f, pos))
            else:  # even position -> right
                right_nodes.append((f, pos))
    
    # Build adjacency: left_idx -> list of right_idx
    adj = [[] for _ in range(len(left_nodes))]
    
    for (u, v) in pairs:
        u_pos = u
        v_pos = v
        # Check which is odd/even
        if u_pos % 2 == 1 and v_pos % 2 == 0:
            # u odd (left), v even (right)
            for li, (lf, lp) in enumerate(left_nodes):
                if lp == u_pos:
                    for ri, (rf, rp) in enumerate(right_nodes):
                        if rp == v_pos and lf == rf:
                            adj[li].append(ri)
        elif u_pos % 2 == 0 and v_pos % 2 == 1:
            # u even (right), v odd (left)
            for li, (lf, lp) in enumerate(left_nodes):
                if lp == v_pos:
                    for ri, (rf, rp) in enumerate(right_nodes):
                        if rp == u_pos and lf == rf:
                            adj[li].append(ri)
    
    # Hopcroft-Karp
    match_left = [-1] * len(left_nodes)
    match_right = [-1] * len(right_nodes)
    
    def bfs():
        from collections import deque
        queue = deque()
        dist = [-1] * len(left_nodes)
        
        for i in range(len(left_nodes)):
            if match_left[i] == -1:
                dist[i] = 0
                queue.append(i)
        
        found = False
        while queue:
            u = queue.popleft()
            for v in adj[u]:
                next_u = match_right[v]
                if next_u == -1:
                    found = True
                elif dist[next_u] == -1:
                    dist[next_u] = dist[u] + 1
                    queue.append(next_u)
        return found, dist
    
    def dfs(u, dist):
        for v in adj[u]:
            next_u = match_right[v]
            if next_u == -1 or (dist[next_u] == dist[u] + 1 and dfs(next_u, dist)):
                match_left[u] = v
                match_right[v] = u
                return True
        dist[u] = -1
        return False
    
    matching = 0
    while True:
        found, dist = bfs()
        if not found:
            break
        for i in range(len(left_nodes)):
            if match_left[i] == -1:
                if dfs(i, dist):
                    matching += 1
    
    return matching

@cocotb.test()
async def test_max_ops(dut):
    """Test max operations module"""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a_i.value = 0
    dut.idx1_i.value = 0
    dut.idx2_i.value = 0
    dut.n.value = 0
    dut.m.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, m, a_array, pairs_array, expected)
    test_cases = [
        (3, 2, [8, 3, 8], [(1,2), (2,3)], 0),
        (3, 2, [8, 12, 8], [(1,2), (2,3)], 2),
        (6, 4, [35, 33, 46, 58, 7, 61], [(4,5), (3,6), (5,6), (1,6)], 0),
        (2, 1, [10, 10], [(1,2)], 2),
        (5, 3, [1, 2, 2, 2, 2], [(2,3), (3,4), (2,5)], 2),
    ]
    
    total_tests = len(test_cases)
    passed_tests = 0
    
    for test_idx, (n, m, a_array, pairs, expected) in enumerate(test_cases):
        print(f"Running test {test_idx+1}: n={n}, m={m}, expected={expected}")
        
        # Load n and m
        dut.n.value = n
        dut.m.value = m
        await RisingEdge(dut.clk)
        
        # Load array values
        dut._log.info("Loading array...")
        for i, val in enumerate(a_array):
            dut.a_i.value = val
            await RisingEdge(dut.clk)
        
        # Load pairs
        dut._log.info("Loading pairs...")
        for (p1, p2) in pairs:
            dut.idx1_i.value = p1
            dut.idx2_i.value = p2
            await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 5000  # cycles
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Test {test_idx+1} timed out!")
        
        # Check result
        result = int(dut.result.value)
        print(f"  Result: {result}, Expected: {expected}")
        
        if result == expected:
            passed_tests += 1
        else:
            print(f"  FAILED: got {result}, expected {expected}")
    
    print(f"
Summary: {passed_tests}/{total_tests} tests passed")
    if passed_tests != total_tests:
        raise TestFailure(f"Only {passed_tests}/{total_tests} tests passed")
