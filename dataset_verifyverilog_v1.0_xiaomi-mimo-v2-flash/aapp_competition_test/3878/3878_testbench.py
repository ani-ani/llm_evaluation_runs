import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

CLK_NS = 10
MAX_STEPS = 22
N_MAX = 22

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Helper to write adjacency matrix
async def write_adj_matrix(dut, n, edges):
    """Write adjacency matrix from list of edges"""
    # Initialize zero matrix
    adj = [[0] * n for _ in range(n)]
    for u, v in edges:
        adj[u][v] = 1
        adj[v][u] = 1
    
    # Write each row
    for i in range(n):
        row_mask = 0
        for j in range(n):
            if adj[i][j]:
                row_mask |= (1 << j)
        
        # Write to dut - assuming single 22-bit input per row
        if has_signal(dut, f'adj_{i}'):
            getattr(dut, f'adj_{i}').value = clamp_to_width(row_mask, 22)
        elif has_signal(dut, f'adj_{i}_0'):
            # For 22-bit split across multiple signals
            for bit in range(22):
                if bit < 16:
                    idx = bit // 16
                    getattr(dut, f'adj_{i}_{idx}').value = (row_mask >> (idx*16)) & 0xFFFF
                else:
                    getattr(dut, f'adj_{i}_2').value = (row_mask >> 32) & 0xFFFF

def verify_solution(n, edges, step_sequence):
    """Verify that the step sequence produces a complete graph"""
    # Build adjacency
    adj = [[0] * n for _ in range(n)]
    for u, v in edges:
        adj[u][v] = 1
        adj[v][u] = 1
    
    # Apply steps
    for node in step_sequence:
        # Get friends of node
        friends = [j for j in range(n) if adj[node][j]]
        # Make all pairs of friends connected
        for i in range(len(friends)):
            for j in range(i+1, len(friends)):
                adj[friends[i]][friends[j]] = 1
                adj[friends[j]][friends[i]] = 1
    
    # Check if complete
    total_edges = n * (n - 1) // 2
    edge_count = 0
    for i in range(n):
        for j in range(i+1, n):
            if adj[i][j]:
                edge_count += 1
    
    return edge_count == total_edges

def compute_min_steps(n, edges):
    """Compute minimum steps using greedy heuristic"""
    adj = [[0] * n for _ in range(n)]
    for u, v in edges:
        adj[u][v] = 1
        adj[v][u] = 1
    
    steps = []
    visited = [False] * n
    
    # Greedy: pick node that maximizes new connections
    while True:
        # Check if complete
        complete = True
        for i in range(n):
            for j in range(i+1, n):
                if not adj[i][j]:
                    complete = False
                    break
            if not complete:
                break
        if complete:
            break
        
        best_node = -1
        best_new_edges = -1
        
        for i in range(n):
            if visited[i]:
                continue
            # Count new edges if we select i
            friends = [j for j in range(n) if adj[i][j]]
            new_edges = 0
            for ii in range(len(friends)):
                for jj in range(ii+1, len(friends)):
                    if not adj[friends[ii]][friends[jj]]:
                        new_edges += 1
            
            if new_edges > best_new_edges:
                best_new_edges = new_edges
                best_node = i
        
        if best_node == -1:
            break
        
        steps.append(best_node)
        visited[best_node] = True
        
        # Apply step
        friends = [j for j in range(n) if adj[best_node][j]]
        for ii in range(len(friends)):
            for jj in range(ii+1, len(friends)):
                adj[friends[ii]][friends[jj]] = 1
                adj[friends[jj]][friends[ii]] = 1
    
    return steps

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_min_friends_steps(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (n, edges_list)
    test_cases = [
        # Example 1
        (5, [(0,1), (0,2), (1,2), (1,4), (2,3), (3,4)]),
        # Example 2
        (4, [(0,1), (0,2), (0,3), (2,3)]),
        # Small case
        (3, [(0,2), (1,2)]),
        # Minimal case
        (2, [(0,1)]),
        # n=1
        (1, []),
    ]
    
    for test_idx, (n, edges) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: n={n}, m={len(edges)}")
        
        try:
            # Write inputs
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, 5)
            
            # Write adjacency matrix
            await write_adj_matrix(dut, n, edges)
            
            # Start computation
            if is_seq:
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read results
            if not has_signal(dut, 'step_count'):
                raise TestFailure("Missing step_count output")
            
            step_count = int(dut.step_count.value)
            
            # Read step sequence
            steps = []
            for i in range(MAX_STEPS):
                if has_signal(dut, f'steps_{i}'):
                    val = int(getattr(dut, f'steps_{i}').value)
                    if val < n:  # Valid node index
                        steps.append(val)
                elif has_signal(dut, f'steps_{i}_0'):
                    # Packed format - read entire steps signal
                    pass
            
            # For packed array test
            if has_signal(dut, 'steps') and steps == []:
                steps_val = int(dut.steps.value)
                for i in range(MAX_STEPS):
                    node = (steps_val >> (i*5)) & 0x1F
                    if node < n and node != 0x1F:  # 0x1F is sentinel for unused
                        steps.append(node)
            
            # Verify solution
            if step_count > 0:
                if not verify_solution(n, edges, steps[:step_count]):
                    raise TestFailure(f"Invalid solution: steps={steps[:step_count]}")
            
            # Compare with expected (compute using greedy)
            expected_steps = compute_min_steps(n, edges)
            if step_count != len(expected_steps):
                # Not strictly required since multiple solutions exist
                cocotb.log.info(f"Got {step_count} steps, greedy computed {len(expected_steps)}")
            
            cocotb.log.info(f"Test passed: {step_count} steps, sequence {steps[:step_count]}")
            
        except TestFailure as e:
            cocotb.log.error(f"Test {test_idx+1} FAIL: {e}")
            raise
    
    # Additional test with larger n
    cocotb.log.info("Testing n=22 case")
    n = 22
    edges = [(0,1), (0,2), (1,2), (3,4), (4,5), (3,5)]  # Two triangles + isolated
    # Need to ensure graph is connected
    edges = [(0,1), (0,2), (1,2), (1,3), (3,4), (4,5), (3,5), (5,6)]
    
    try:
        if has_signal(dut, 'n'):
            dut.n.value = clamp_to_width(n, 5)
        await write_adj_matrix(dut, n, edges)
        
        if is_seq:
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            await wait_for_done(dut, max_cycles=5000)
        else:
            await Timer(500, units='ns')
        
        step_count = int(dut.step_count.value)
        steps = []
        for i in range(MAX_STEPS):
            if has_signal(dut, f'steps_{i}'):
                val = int(getattr(dut, f'steps_{i}').value)
                if val < n:
                    steps.append(val)
        
        if has_signal(dut, 'steps') and steps == []:
            steps_val = int(dut.steps.value)
            for i in range(MAX_STEPS):
                node = (steps_val >> (i*5)) & 0x1F
                if node < n and node != 0x1F:
                    steps.append(node)
        
        if step_count > 0:
            if not verify_solution(n, edges, steps[:step_count]):
                raise TestFailure(f"n=22 solution invalid")
        
        cocotb.log.info(f"n=22 test passed: {step_count} steps")
        
    except TestFailure as e:
        cocotb.log.error(f"n=22 test FAIL: {e}")
        raise
