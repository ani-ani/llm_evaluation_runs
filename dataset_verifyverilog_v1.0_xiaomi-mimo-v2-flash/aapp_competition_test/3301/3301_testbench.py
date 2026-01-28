import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MAX_NODES = 16
MAX_EDGES = 32
DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 5000

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0: return 0
    if v > max_val: return max_val
    return v

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Test Case 1
@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_case_1(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Input Data
    # Nodes: 1-6 -> 0-5
    # Edges: 
    # 1 2 5 -> 0 1 5
    # 1 3 1 -> 0 2 1
    # 2 6 6 -> 1 5 6
    # 2 3 6 -> 1 2 6
    # 4 2 3 -> 3 1 3
    # 3 4 1 -> 2 3 1
    # 4 5 1 -> 3 4 1
    # 5 6 1 -> 4 5 1
    edges_src = [0, 0, 1, 1, 3, 2, 3, 4]
    edges_dst = [1, 2, 5, 2, 1, 3, 4, 5]
    edges_wt  = [5, 1, 6, 6, 3, 1, 1, 1]
    num_edges = 8
    num_nodes = 6
    src_node = 0 # X=1
    dst_node = 5 # Y=6
    # SWERC nodes: 1 3 6 5 4 -> 0, 2, 5, 4, 3
    swerc_nodes = [0]*16
    for n in [0, 2, 5, 4, 3]: swerc_nodes[n] = 1
    
    # Write Inputs
    dut.num_nodes.value = num_nodes
    dut.num_edges.value = num_edges
    dut.src_node.value = src_node
    dut.dst_node.value = dst_node
    
    for i in range(32):
        if i < num_edges:
            dut.edges_src[i].value = edges_src[i]
            dut.edges_dst[i].value = edges_dst[i]
            dut.edges_wt[i].value = edges_wt[i]
        else:
            dut.edges_src[i].value = 0
            dut.edges_dst[i].value = 0
            dut.edges_wt[i].value = 0
            
    for i in range(16):
        dut.swerc_nodes[i].value = swerc_nodes[i]
        
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    await wait_for_done(dut)
    
    # Check Result
    result = int(dut.result.value)
    # Expected output is 3
    if result != 3:
        raise TestFailure(f"Test 1 Failed. Expected 3, got {result}")

# Test Case 2
@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_case_2(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Input Data
    # Nodes 1-3 -> 0-2
    # Edges:
    # 1 2 6 -> 0 1 6
    # 1 3 2 -> 0 2 2
    # 1 2 7 -> 0 1 7 (duplicate edge)
    # 2 3 3 -> 1 2 3
    edges_src = [0, 0, 0, 1]
    edges_dst = [1, 2, 1, 2]
    edges_wt  = [6, 2, 7, 3]
    num_edges = 4
    num_nodes = 3
    src_node = 0 # X=1
    dst_node = 1 # Y=2
    # SWERC nodes: 1 2 -> 0, 1
    swerc_nodes = [0]*16
    swerc_nodes[0] = 1
    swerc_nodes[1] = 1
    
    # Write Inputs
    dut.num_nodes.value = num_nodes
    dut.num_edges.value = num_edges
    dut.src_node.value = src_node
    dut.dst_node.value = dst_node
    
    for i in range(32):
        if i < num_edges:
            dut.edges_src[i].value = edges_src[i]
            dut.edges_dst[i].value = edges_dst[i]
            dut.edges_wt[i].value = edges_wt[i]
        else:
            dut.edges_src[i].value = 0
            dut.edges_dst[i].value = 0
            dut.edges_wt[i].value = 0
            
    for i in range(16):
        dut.swerc_nodes[i].value = swerc_nodes[i]
        
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    await wait_for_done(dut)
    
    # Check Result (Infinity sentinel)
    result = int(dut.result.value)
    # Assuming 0xFFFFFFFF for Infinity
    if result != 0xFFFFFFFF:
        raise TestFailure(f"Test 2 Failed. Expected Infinity (0xFFFFFFFF), got {result}")

# Test Case 3
@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_case_3(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Input Data
    # Nodes 1-4 -> 0-3
    # Edges:
    # 1 2 1 -> 0 1 1
    # 1 3 1 -> 0 2 1
    # 2 4 1 -> 1 3 1
    # 3 4 1 -> 2 3 1
    edges_src = [0, 0, 1, 2]
    edges_dst = [1, 2, 3, 3]
    edges_wt  = [1, 1, 1, 1]
    num_edges = 4
    num_nodes = 4
    src_node = 0 # X=1
    dst_node = 3 # Y=4
    # SWERC nodes: 1 2 4 -> 0, 1, 3
    swerc_nodes = [0]*16
    swerc_nodes[0] = 1
    swerc_nodes[1] = 1
    swerc_nodes[3] = 1
    
    # Write Inputs
    dut.num_nodes.value = num_nodes
    dut.num_edges.value = num_edges
    dut.src_node.value = src_node
    dut.dst_node.value = dst_node
    
    for i in range(32):
        if i < num_edges:
            dut.edges_src[i].value = edges_src[i]
            dut.edges_dst[i].value = edges_dst[i]
            dut.edges_wt[i].value = edges_wt[i]
        else:
            dut.edges_src[i].value = 0
            dut.edges_dst[i].value = 0
            dut.edges_wt[i].value = 0
            
    for i in range(16):
        dut.swerc_nodes[i].value = swerc_nodes[i]
        
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    await wait_for_done(dut)
    
    # Check Result (Impossible sentinel)
    result = int(dut.result.value)
    # Assuming 0xFFFFFFFE for Impossible
    if result != 0xFFFFFFFE:
        raise TestFailure(f"Test 3 Failed. Expected Impossible (0xFFFFFFFE), got {result}")