import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MAX_NODES = 16
MAX_COLORS = 16
DATA_WIDTH = 4
RESULT_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 5000

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
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Helper to compute subtree nodes using Python logic (since N is small)
def get_subtree_nodes(node, parents):
    # parents list index 0 corresponds to node 2, value is parent node id (1-based)
    # Construct adjacency
    adj = {i: [] for i in range(1, MAX_NODES + 1)}
    for i, p in enumerate(parents):
        child = i + 2
        if child > MAX_NODES: break
        adj[p].append(child)
    
    stack = [node]
    subtree = []
    while stack:
        curr = stack.pop()
        subtree.append(curr)
        for child in adj[curr]:
            stack.append(child)
    return subtree

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_magical_colors(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational
        await Timer(100, units='ns')

    # Test Case 1: Sample Input 2
    # 7 nodes
    # Colors: 1 2 2 1 1 2 1 (indices 1-7)
    # Parents: 1 1 1 2 2 3 (indices 2-7)
    
    N = 7
    colors_init = [1, 2, 2, 1, 1, 2, 1] # 0-indexed
    parents = [1, 1, 1, 2, 2, 3] # 0-indexed (node 2 to 7)
    
    # Pre-compute subtree info for verification
    # Subtree 1: all nodes 1-7 -> colors: 1,2,2,1,1,2,1 -> 1:4(even), 2:3(odd) -> Magical=1 (Color 2)
    # Subtree 2: nodes 2,4,5,6 -> colors: 2,1,1,2 -> 2:2(even), 1:2(even) -> Magical=0
    # Subtree 3: nodes 3,7 -> colors: 2,1 -> 2:1(odd), 1:1(odd) -> Magical=2
    
    expected_results = {
        1: 1, 2: 0, 3: 2, 4: 1, 5: 1, 6: 1, 7: 1
    }

    # Initialize DUT (Assuming we can load initial state via inputs or reset behavior)
    # For this test, we will perform updates to set the state as required
    
    # 1. Set Colors
    # Since the prompt implies a loaded state, we simulate initialization by updating nodes
    # Node 1..7 colors
    for i in range(7):
        node = i + 1
        color = colors_init[i]
        
        if has_signal(dut, 'op_type'):
            dut.op_type.value = 1 # Update
            dut.node_idx.value = node
            dut.new_color.value = color - 1 # 0-15 range
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            # Direct assignment for combinational or simpler interface
            # Assuming dut.colors array exists
            if has_signal(dut, f'colors_{node-1}'):
                getattr(dut, f'colors_{node-1}').value = color - 1
            elif has_signal(dut, 'colors'):
                # Array
                dut.colors[node-1].value = color - 1
    
    # 2. Set Parents (Assuming loaded on reset or separate port)
    # If parent array needs to be set explicitly:
    for i in range(6): # 6 edges
        child = i + 2
        parent = parents[i]
        if has_signal(dut, f'parent_{child-1}'):
            getattr(dut, f'parent_{child-1}').value = parent - 1
        elif has_signal(dut, 'parents'):
            dut.parents[child-1].value = parent - 1

    # 3. Run Queries
    # Query 1: Node 1 (Expected 1)
    await run_query(dut, 1, 1)
    
    # Query 2: Node 2 (Expected 0)
    await run_query(dut, 2, 0)

    # Query 3: Node 3 (Expected 2)
    await run_query(dut, 3, 2)

    # Query 4: Node 4 (Expected 1)
    await run_query(dut, 4, 1)

    # Query 5: Node 5 (Expected 1)
    await run_query(dut, 5, 1)

    # Query 6: Node 6 (Expected 1)
    await run_query(dut, 6, 1)

    # Query 7: Node 7 (Expected 1)
    await run_query(dut, 7, 1)

    cocotb.log.info("All tests passed!")

async def run_query(dut, node, expected):
    if has_signal(dut, 'op_type'):
        dut.op_type.value = 0 # Query
        dut.node_idx.value = node
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        
        # Read result
        if is_value_defined(dut.result.value):
            res = int(dut.result.value)
            cocotb.log.info(f"Query Node {node}: Got {res}, Expected {expected}")
            if res != expected:
                raise TestFailure(f"Node {node} failed: got {res}, expected {expected}")
        else:
            raise TestFailure("Result signal undefined")
    else:
        # Combinational check
        await Timer(10, units='ns')
        # If combinational, result should be valid immediately
        if is_value_defined(dut.result.value):
            res = int(dut.result.value)
            cocotb.log.info(f"Query Node {node}: Got {res}, Expected {expected}")
            if res != expected:
                raise TestFailure(f"Node {node} failed: got {res}, expected {expected}")
