import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# --- MANDATORY HELPERS ---
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# --- GRAPH HELPERS ---
def map_node(python_val):
    # -2 -> 8, -1 -> 9, 0-7 -> 0-7
    if python_val == -2: return 8
    if python_val == -1: return 9
    return python_val

def setup_graph(dut, p, r, l, lines):
    # Setup edges into the arrays
    # Inputs: edges_valid, edge_u, edge_v
    # We assume inputs are packed or arrayed. 
    # Assuming arrayed inputs as per spec: u[0:15], v[0:15], valid[0:15]
    
    # Initialize all valid bits to 0
    if has_signal(dut, 'edges_valid'):
        # If it's a single vector
        dut.edges_valid.value = 0
    elif has_signal(dut, 'valid'):
        # If it's an array of scalars
        for i in range(16):
            getattr(dut, f'valid_{i}').value = 0
            
    for i, (u_str, v_str) in enumerate(lines):
        if i >= 16: break # Scale limit
        u = int(u_str); v = int(v_str)
        u = map_node(u); v = map_node(v)
        
        # Set Valid
        if has_signal(dut, 'edges_valid'):
            # Assuming bit vector
            val = int(dut.edges_valid.value)
            val |= (1 << i)
            dut.edges_valid.value = val
        else:
            getattr(dut, f'valid_{i}').value = 1
            
        # Set Endpoints
        if has_signal(dut, 'edge_u'):
            # Assuming array of signals
            getattr(dut, f'edge_u_{i}').value = u
            getattr(dut, f'edge_v_{i}').value = v
        elif has_signal(dut, 'u_0'):
             getattr(dut, f'u_{i}').value = u
             getattr(dut, f'v_{i}').value = v
             
@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_river_crossing(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # --- TEST CASE 1: Sample 1 (2 People) ---
    # Expected: 6
    # Graph: -2-0-(-1), -2-1-0, 2-1, 2-3-(-1)
    # Path 1: -2 -> 0 -> -1 (Length 2)
    # Path 2: -2 -> 1 -> 0 (Fail, 0-1 used?), wait. 
    # Edges: (8,0), (0,9), (8,1), (1,0), (2,1), (2,3), (3,9)
    # P1: 8->0->9 (len 2). Removes (8,0), (0,9).
    # P2: 8->1->0 (stuck). 8->1->2->3->9? (8,1) ok, (1,2) exists? (2,1) is undirected? Problem says pairs.
    # Undirected graph. 
    # P1 path 8-0-9. Edges removed.
    # P2 path 8-1-2-3-9. Length 4. Total 6.
    
    lines = ["-2 0", "0 -1", "-2 1", "1 0", "2 1", "2 3", "3 -1"]
    setup_graph(dut, 2, 4, 7, lines)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    res = int(dut.result.value)
    # Check result format: Success = value, Fail = value + 16
    # 6 is 0x06. Success.
    if res != 6:
        raise TestFailure(f"Test 1 failed: Expected 6, got {res}")
        
    # --- RESET FOR NEXT TEST ---
    await reset_dut(dut)
    
    # --- TEST CASE 2: Sample 2 (3 People, Impossible) ---
    # Input: 3 2 5
    # -2 0
    # -2 1
    # 0 1
    # 1 -1
    # 0 -1
    # Nodes: 0, 1. Banks: 8, 9.
    # Edges: (8,0), (8,1), (0,1), (1,9), (0,9).
    # P1: 8->0->9 (len 2). Removes (8,0), (0,9).
    # P2: 8->1->9 (len 2). Removes (8,1), (1,9).
    # P3: No edges from 8. Impossible.
    # Output: "1 people left behind" -> 1.
    
    lines = ["-2 0", "-2 1", "0 1", "1 -1", "0 -1"]
    setup_graph(dut, 3, 2, 5, lines)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    res = int(dut.result.value)
    # Fail bit is bit 4. Value should be 1 (people left) + 16 (fail flag).
    if res != 17: # 0b10001
        raise TestFailure(f"Test 2 failed: Expected 17 (1 left + flag), got {res}")
        
    cocotb.log.info("All tests passed!")