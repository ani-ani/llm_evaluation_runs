import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_constrained_mst(dut):
    """Test constrained MST module with multiple cases."""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    dut.k.value = 0
    dut.w.value = 0
    dut.special_nodes_mask.value = 0
    for i in range(16):
        dut.edge_node_a[i].value = 0
        dut.edge_node_b[i].value = 0
        dut.edge_cost[i].value = 0
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Sample Input
    # n=3, m=3, k=1, w=2
    # Special: 2
    # Edges: 1-2 (2), 1-3 (1), 2-3 (3)
    # Need spanning tree (2 edges) with exactly 2 special-nonspecial edges.
    # Edges: 1-2 (S-NS), 2-3 (S-NS) -> Cost 2+3=5. Valid.
    # Edges: 1-2, 1-3 -> 1-2 (S-NS), 1-3 (NS-NS) -> 1 S-NS (fail).
    # Edges: 1-3, 2-3 -> 1-3 (NS-NS), 2-3 (S-NS) -> 1 S-NS (fail).
    # Result should be 5.
    
    dut.n.value = 3
    dut.m.value = 3
    dut.k.value = 1
    dut.w.value = 2
    # Node 2 is special (mask bit 1 set)
    dut.special_nodes_mask.value = 0b010 
    
    # Edge 0: 1-2 cost 2
    dut.edge_node_a[0].value = 1
    dut.edge_node_b[0].value = 2
    dut.edge_cost[0].value = 2
    # Edge 1: 1-3 cost 1
    dut.edge_node_a[1].value = 1
    dut.edge_node_b[1].value = 3
    dut.edge_cost[1].value = 1
    # Edge 2: 2-3 cost 3
    dut.edge_node_a[2].value = 2
    dut.edge_node_b[2].value = 3
    dut.edge_cost[2].value = 3
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 100000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test case 1: Did not finish in time")
        
    if dut.result.value != 5:
        raise TestFailure(f"Test case 1: Expected 5, got {dut.result.value}")
    
    print("Test case 1 passed")

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: Impossible case
    # n=3, m=1, k=1, w=1
    # Special: 2
    # Edge: 1-2 cost 2
    # Need spanning tree (2 edges) with w=1. Only 1 edge available. Impossible.
    
    dut.n.value = 3
    dut.m.value = 1
    dut.k.value = 1
    dut.w.value = 1
    dut.special_nodes_mask.value = 0b010
    
    dut.edge_node_a[0].value = 1
    dut.edge_node_b[0].value = 2
    dut.edge_cost[0].value = 2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
        
    if dut.done.value != 1:
        raise TestFailure("Test case 2: Did not finish in time")
        
    # Check for -1 (0xFFFFFFFF)
    if dut.result.value != 0xFFFFFFFF:
        raise TestFailure(f"Test case 2: Expected -1 (0xFFFFFFFF), got {dut.result.value}")
        
    print("Test case 2 passed")

    # Test Case 3: Larger graph, multiple valid trees
    # n=4, m=5, k=2, w=2
    # Special: 1, 2
    # Edges:
    # 1-2 (S-S, cost 1)
    # 1-3 (S-NS, cost 5)
    # 2-4 (S-NS, cost 5)
    # 3-4 (NS-NS, cost 1)
    # 1-4 (S-NS, cost 10)
    
    # We need a spanning tree (3 edges) with exactly 2 S-NS edges.
    # Option A: 1-2 (S-S), 1-3 (S-NS), 2-4 (S-NS). Cost 1+5+5=11. Valid.
    # Option B: 1-2 (S-S), 1-3 (S-NS), 3-4 (NS-NS). Cost 1+5+1=7. S-NS count=1. Invalid.
    # Option C: 1-2 (S-S), 2-4 (S-NS), 3-4 (NS-NS). Cost 1+5+1=7. S-NS count=1. Invalid.
    # Option D: 1-3 (S-NS), 2-4 (S-NS), 3-4 (NS-NS). Cost 5+5+1=11. S-NS count=2. Valid.
    # Option E: 1-4 (S-NS), 2-4 (S-NS), 3-4 (NS-NS). Cost 10+5+1=16. S-NS count=2. Valid.
    # Option F: 1-2 (S-S), 1-4 (S-NS), 3-4 (NS-NS). Cost 1+10+1=12. S-NS count=1. Invalid.
    
    # Min cost valid is 11.
    
    dut.n.value = 4
    dut.m.value = 5
    dut.k.value = 2
    dut.w.value = 2
    dut.special_nodes_mask.value = 0b0011 # Nodes 1 and 2
    
    dut.edge_node_a[0].value = 1
    dut.edge_node_b[0].value = 2
    dut.edge_cost[0].value = 1
    
    dut.edge_node_a[1].value = 1
    dut.edge_node_b[1].value = 3
    dut.edge_cost[1].value = 5
    
    dut.edge_node_a[2].value = 2
    dut.edge_node_b[2].value = 4
    dut.edge_cost[2].value = 5
    
    dut.edge_node_a[3].value = 3
    dut.edge_node_b[3].value = 4
    dut.edge_cost[3].value = 1
    
    dut.edge_node_a[4].value = 1
    dut.edge_node_b[4].value = 4
    dut.edge_cost[4].value = 10
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
        
    if dut.done.value != 1:
        raise TestFailure("Test case 3: Did not finish in time")
        
    if dut.result.value != 11:
        raise TestFailure(f"Test case 3: Expected 11, got {dut.result.value}")
        
    print("Test case 3 passed")
    print("All tests passed!")
