import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_resource_miner(dut):
    # Setup
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Example 1 (3 nodes)
    # Nodes: 1->2, 2->3, 3->1 (Cycle)
    # Iron at 2 (index 1), Coal at 3 (index 2)
    # Dist from 1: d1=0, d2=1, d3=2 (via 2) or direct 2
    # Actually 1->2 (iron), 2->3 (coal). Dist Iron=1, Coal=2. Settlers = 1+2-1 = 2.
    
    # Configure Graph (Nodes 0..2 mapped to input 1..3)
    # Edges: 0->1, 1->2, 2->0
    edges = [
        [1],    # Node 0 -> 1
        [2],    # Node 1 -> 2
        [0]     # Node 2 -> 0
    ]
    
    dut.iron_mask.value = 0b00000010  # Node 1
    dut.coal_mask.value = 0b00000100  # Node 2
    
    # Load Graph Data
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # We need to pump data into the module.
    # Assuming interface requires 16 cycles of data input for the 3 nodes.
    for node_idx in range(16):
        if node_idx < len(edges) and edges[node_idx]:
            # Pack edges into 8-bit bus? Spec said 8-bit data, 4-bit addr.
            # Let's assume we just send 1 edge per cycle for simplicity or packed
            # Based on spec 'graph_in_data' is 8-bit. 
            # If multiple edges exist, we might need to send them sequentially to same address or different addresses.
            # Let's assume a simplified protocol where we send (addr << 4) | edge_idx or similar.
            # Actually, spec says: graph_in_addr (4-bit), graph_in_data (8-bit), graph_in_valid.
            # Let's assume 'graph_in_data' is the TARGET node ID (0-15).
            # And we need to write multiple edges. 
            # To keep it simple for the testbench, we'll iterate the edges list and write them.
            for edge_target in edges[node_idx]:
                dut.graph_in_addr.value = node_idx
                dut.graph_in_data.value = edge_target
                dut.graph_in_valid.value = 1
                await RisingEdge(dut.clk)
                dut.graph_in_valid.value = 0
                await RisingEdge(dut.clk) # Delay between edges
        else:
            # Dummy writes or just wait
            dut.graph_in_valid.value = 0
            await RisingEdge(dut.clk)
            
    # Wait for computation (BFS + Scan)
    # We need a way to detect 'done' or wait max cycles
    max_cycles = 100
    done = False
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
    
    if not done:
        raise TestFailure("Did not finish in 100 cycles")
        
    result = int(dut.result.value)
    # Expected: 1 (to iron) + 2 (to coal) - 1 = 2
    if result != 2:
        raise TestFailure(f"Test 1 Failed: Expected 2, got {result}")
        
    cocotb.log.info(f"Test 1 Passed. Result: {result}")
    
    # --- Test Case 2: Impossible (Disconnected) ---
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Graph: 1->2, 1->1 (self loop), 2->1 (Example 2)
    # Iron at 2 (idx 1), Coal at 3 (idx 2).
    # Node 2 (idx 2) is unreachable from Node 1 (idx 0) if graph only has edges for 0->1 and 1->0? 
    # Input "2 1 2" means Node 3 (idx 2) points to 2 (idx 1).
    # We start at node 1 (idx 0).
    # Edges: 0->1, 1->0. Node 2 is isolated (or points to 1, but we can't reach 2).
    
    edges2 = [
        [1],    # Node 0 -> 1
        [0],    # Node 1 -> 0
        []      # Node 2 (isolated)
    ]
    dut.iron_mask.value = 0b00000010  # Node 1
    dut.coal_mask.value = 0b00000100  # Node 2 (Unreachable)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for node_idx in range(16):
        if node_idx < len(edges2):
            for edge_target in edges2[node_idx]:
                dut.graph_in_addr.value = node_idx
                dut.graph_in_data.value = edge_target
                dut.graph_in_valid.value = 1
                await RisingEdge(dut.clk)
                dut.graph_in_valid.value = 0
                await RisingEdge(dut.clk)
        else:
            dut.graph_in_valid.value = 0
            await RisingEdge(dut.clk)
            
    done = False
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
            
    if not done:
        raise TestFailure("Did not finish in 100 cycles")
        
    result = int(dut.result.value)
    # Expected: 255 (Impossible)
    if result != 255:
        raise TestFailure(f"Test 2 Failed: Expected 255 (impossible), got {result}")
        
    cocotb.log.info(f"Test 2 Passed. Result: {result} (Impossible)")
