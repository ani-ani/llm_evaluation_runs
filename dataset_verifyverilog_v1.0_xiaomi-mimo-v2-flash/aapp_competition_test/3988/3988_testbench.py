import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0: return 0
    if v > max_val: return max_val
    return v

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Simulation constraints
MAX_N = 16
MAX_M = 16

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    # Clear inputs
    dut.n_in.value = 0
    dut.m_in.value = 0
    dut.s_in.value = 0
    dut.edge_type.value = 0
    dut.edge_u.value = 0
    dut.edge_v.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_edges(dut, edges, n):
    # Pack arrays
    type_vec = 0
    u_vec = 0
    v_vec = 0
    
    for i, (t, u, v) in enumerate(edges):
        # type: 1 or 2 -> store as 1 or 2 (2 bits enough, but packed in vector)
        type_vec |= (t & 0x3) << (2*i)
        u_vec |= ((u) & 0xF) << (4*i)
        v_vec |= ((v) & 0xF) << (4*i)
        
    dut.edge_type.value = type_vec
    dut.edge_u.value = u_vec
    dut.edge_v.value = v_vec

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_mixed_graph(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test Case 1: Simple example from prompt
    # 2 nodes, 1 dir (1->2), 1 undir (2-1)
    # Start at 1. Max reach=2. Min reach=2 (since undir connects back).
    # Actually, example 1: 2 2 1
    # 1 1 2 (dir)
    # 2 2 1 (undir)
    # Max: 2 (dir 1->2, undir 2->1 or 1->2). Reach 2.
    # Min: 2. Even if undir is 2->1, we start at 1. Dir 1->2 gives 2.
    
    n = 2
    m = 2
    s = 1
    edges = [(1, 1, 2), (2, 2, 1)] # (type, u, v)
    
    dut.n_in.value = n
    dut.m_in.value = m
    dut.s_in.value = s
    
    await write_edges(dut, edges, n)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    max_reach = int(dut.max_reach.value)
    min_reach = int(dut.min_reach.value)
    
    # Check max
    if max_reach < 2:
        raise TestFailure(f"Test 1 Max Reach: Expected 2, got {max_reach}")
        
    # Check min
    if min_reach < 2:
        raise TestFailure(f"Test 1 Min Reach: Expected 2, got {min_reach}")
        
    cocotb.log.info(f"Test 1 Passed. Max: {max_reach}, Min: {min_reach}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 2: Larger example
    # 6 6 3
    # 2 2 6
    # 1 4 5
    # 2 3 4
    # 1 4 1
    # 1 3 1
    # 2 2 3
    
    # Manual analysis:
    # Nodes: 1-6. Start 3.
    # Edges:
    # 1. 2-6 (undir)
    # 2. 4->5 (dir)
    # 3. 3-4 (undir)
    # 4. 4->1 (dir)
    # 5. 3->1 (dir)
    # 6. 2-3 (undir)
    
    # Max Reach:
    # Start at 3.
    # Dir: 3->1. 3->? No.
    # Undir 3-4: Orient 3->4.
    # Now at 4. Dir: 4->5, 4->1.
    # Undir 2-3: Orient 3<-2 (so 3 can reach 2? No, edge is 3-2). 
    # Wait, if 3->2, then we reach 2.
    # If 2-6, orient 2->6. Reach 6.
    # Reach set: {3, 1, 4, 5, 2, 6} -> 6 nodes. Correct.
    
    # Min Reach:
    # Start at 3.
    # We want to minimize reach.
    # Undir 3-4: If we orient 4->3, we don't go to 4 from 3.
    # Undir 2-3: If we orient 2->3, we don't go to 2 from 3.
    # Directed edges are fixed: 3->1.
    # So we reach {3, 1}. Count 2. Correct.
    
    n = 6
    m = 6
    s = 3
    # (type, u, v)
    edges = [
        (2, 2, 6),
        (1, 4, 5),
        (2, 3, 4),
        (1, 4, 1),
        (1, 3, 1),
        (2, 2, 3)
    ]
    
    dut.n_in.value = n
    dut.m_in.value = m
    dut.s_in.value = s
    
    await write_edges(dut, edges, n)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    max_reach = int(dut.max_reach.value)
    min_reach = int(dut.min_reach.value)
    
    # Allow some flexibility in case of ties or implementation quirks, but standard solution is strict
    # Max should be 6
    if max_reach != 6:
        raise TestFailure(f"Test 2 Max Reach: Expected 6, got {max_reach}")
        
    # Min should be 2
    if min_reach != 2:
        raise TestFailure(f"Test 2 Min Reach: Expected 2, got {min_reach}")
        
    cocotb.log.info(f"Test 2 Passed. Max: {max_reach}, Min: {min_reach}")
