import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper to convert integer to binary string representation
def int_to_bin(val, width):
    return format(val, f'0{width}b')

@cocotb.test()
async def test_min_scc_finder(dut):
    """Test the min_scc_finder module with various graph inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.edge_valid.value = 0
    dut.src_node.value = 0
    dut.dst_node.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Simple SCC of size 1 (Node 2), Node 2 -> Node 2 (Self loop)
    # Graph: 1->2, 2->2. SCCs: {1}, {2}. {2} has size 1, no outgoing edges (if 1->2 is considered outgoing to {1})
    # Let's do: 1->2, 2->1. SCC: {1,2} size 2. 
    # Let's do: 2->2 (self loop). Node 2 is sink.
    # Input: Edge 2->2 (nodes are 1-based in prompt but 0-based in hardware usually, let's stick to 0-based for logic)
    # Wait, prompt says nodes 1..10. Hardware usually 0..9. Let's assume prompt indices map 1:1 to 0:9.
    # Test graph: Node 1 -> Node 2, Node 2 -> Node 2. (Indices 0 and 1)
    # SCC {1} (Node 0) size 1, edges 0->1. Outgoing to {1} (Node 1).
    # SCC {1} (Node 1) size 1, edges 1->1. No outgoing to other SCCs.
    # Expected: Size 1, Node 1.
    
    edges_test1 = [
        (0, 1), # Node 1 -> Node 2
        (1, 1)  # Node 2 -> Node 2
    ]
    
    # Start loading
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for src, dst in edges_test1:
        dut.edge_valid.value = 1
        dut.src_node.value = src
        dut.dst_node.value = dst
        await RisingEdge(dut.clk)
    
    dut.edge_valid.value = 0
    
    # Wait for done
    timeout = 1000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for done signal")
        
    # Check result
    size = int(dut.result_size.value)
    nodes = [int(dut.result_nodes[i].value) for i in range(10)]
    active_nodes = [n for n in nodes if n != 0]
    
    print(f"Test 1 Result: Size={size}, Nodes={active_nodes}")
    if size != 1:
        raise TestFailure(f"Expected size 1, got {size}")
    if 1 not in active_nodes: # Node index 1 corresponds to node 2 in 1-based
        raise TestFailure(f"Expected node 1 in result")
        
    await RisingEdge(dut.clk)
    
    # Test Case 2: Cyclic SCC of size 2, and a separate sink SCC of size 1
    # Graph: 0->1, 1->0 (Cycle), 2->2 (Sink)
    # SCC {0,1} size 2, outgoing 0? No.
    # SCC {2} size 1, outgoing 0? No.
    # Min size is 1.
    
    # Reset for next test (assuming external reset or reload)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    edges_test2 = [
        (0, 1),
        (1, 0),
        (2, 2)
    ]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for src, dst in edges_test2:
        dut.edge_valid.value = 1
        dut.src_node.value = src
        dut.dst_node.value = dst
        await RisingEdge(dut.clk)
    
    dut.edge_valid.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for done signal")
        
    size = int(dut.result_size.value)
    nodes = [int(dut.result_nodes[i].value) for i in range(10)]
    active_nodes = [n for n in nodes if n != 0]
    
    print(f"Test 2 Result: Size={size}, Nodes={active_nodes}")
    if size != 1:
        raise TestFailure(f"Expected size 1, got {size}")
    if 2 not in active_nodes:
        raise TestFailure(f"Expected node 2 in result")
        
    await RisingEdge(dut.clk)
    
    # Test Case 3: All nodes connected in one SCC
    # Graph: 0->1, 1->2, 2->0
    # SCC {0,1,2} size 3. No outgoing. Min size 3.
    
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    edges_test3 = [
        (0, 1),
        (1, 2),
        (2, 0)
    ]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for src, dst in edges_test3:
        dut.edge_valid.value = 1
        dut.src_node.value = src
        dut.dst_node.value = dst
        await RisingEdge(dut.clk)
    
    dut.edge_valid.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for done signal")
        
    size = int(dut.result_size.value)
    nodes = [int(dut.result_nodes[i].value) for i in range(10)]
    active_nodes = [n for n in nodes if n != 0]
    
    print(f"Test 3 Result: Size={size}, Nodes={active_nodes}")
    if size != 3:
        raise TestFailure(f"Expected size 3, got {size}")
    if set(active_nodes) != {0, 1, 2}:
        raise TestFailure(f"Expected {{0, 1, 2}} in result")

    print("All tests passed!")
