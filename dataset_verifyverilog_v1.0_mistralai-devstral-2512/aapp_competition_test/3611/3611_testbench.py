import cocotb
from cocotb.triggers import Timer, RisingEdge, Join
from cocotb.clock import Clock
from cocotb.result import TestFailure
from collections import deque
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'edge_valid'): dut.edge_valid.value = 0
    if has_signal(dut, 'config_done'): dut.config_done.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Bellman-Ford reference implementation
def get_shortest_paths(N, edges, s, t):
    INF = 10**18
    # Forward distances
    dist_s = [INF] * N
    dist_s[s] = 0
    for _ in range(N-1):
        updated = False
        for u, v, w in edges:
            if dist_s[u] != INF and dist_s[u] + w < dist_s[v]:
                dist_s[v] = dist_s[u] + w
                updated = True
        if not updated: break
    
    # Reverse graph distances (to t)
    rev_edges = [(v, u, w) for u, v, w in edges]
    dist_t = [INF] * N
    dist_t[t] = 0
    for _ in range(N-1):
        updated = False
        for u, v, w in rev_edges:
            if dist_t[u] != INF and dist_t[u] + w < dist_t[v]:
                dist_t[v] = dist_t[u] + w
                updated = True
        if not updated: break
    
    return dist_s, dist_t

def solve_critical(N, edges, s, t):
    dist_s, dist_t = get_shortest_paths(N, edges, s, t)
    if dist_s[t] == 10**18: return []
    
    critical = []
    for u in range(N):
        if dist_s[u] == 10**18 or dist_t[u] == 10**18:
            continue
        # Check if on some shortest path
        if dist_s[u] + dist_t[u] == dist_s[t]:
            critical.append(u)
    return critical

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_shortest_path_critical(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test Cases
    test_cases = [
        (4, [(0,1,100), (0,2,100), (1,3,100), (2,3,100)], 0, 3),
        (7, [(0,1,100), (0,2,100), (1,3,100), (2,3,100), (3,4,100), (3,5,100), (4,6,100), (5,6,100)], 0, 6)
    ]

    for i, (N, edges, s, t) in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}: N={N}, s={s}, t={t}")
        
        # Calculate expected
        expected_critical = solve_critical(N, edges, s, t)
        dut._log.info(f"Expected critical nodes: {expected_critical}")
        
        # 1. Configure Graph via Stream
        dut.src_node.value = s
        dut.dst_node.value = t
        
        for u, v, w in edges:
            dut.edge_valid.value = 1
            dut.u.value = u
            dut.v.value = v
            dut.w.value = w
            await RisingEdge(dut.clk)
        
        dut.edge_valid.value = 0
        dut.config_done.value = 1
        await RisingEdge(dut.clk)
        dut.config_done.value = 0
        
        # 2. Start Computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # 3. Collect Results
        collected = []
        cycles = 0
        max_cycles = 2000
        
        while True:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > max_cycles:
                raise TestFailure(f"Timeout in test case {i+1}")
            
            if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                node = int(dut.result_idx.value)
                is_crit = int(dut.is_critical.value)
                if is_crit:
                    collected.append(node)
                    dut._log.info(f"Found critical node: {node}")
            
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        
        # Verify
        collected.sort()
        if collected != expected_critical:
            raise TestFailure(f"Case {i+1} failed. Got {collected}, Expected {expected_critical}")
        
        # Reset for next case
        await reset_dut(dut)