import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

@cocotb.test()
async def test_max_independent_set(dut):
    """Test maximum independent set calculation for various small graphs"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_nodes.value = 0
    dut.num_edges.value = 0
    for i in range(8):
        dut.edge_a[i].value = 0
        dut.edge_b[i].value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 2 nodes, 1 edge (1-2) => MIS = 1
    dut.num_nodes.value = 2
    dut.num_edges.value = 1
    dut.edge_a[0].value = 0  # Node 1 -> index 0
    dut.edge_b[0].value = 1  # Node 2 -> index 1
    # Clear remaining edges
    for i in range(1, 8):
        dut.edge_a[i].value = 0
        dut.edge_b[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (256 cycles for brute force)
    for _ in range(260):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 1, f"Test 1 failed: expected 1, got {dut.result.value}"
    print(f"Test 1 PASSED: 2-node graph, 1 edge -> MIS = {dut.result.value}")
    
    await RisingEdge(dut.clk)
    await Timer(5, units='ns')
    
    # Test case 2: 4 nodes, 5 edges (cycle 1-2-3-4-1 plus edge 1-3) => MIS = 2
    # Graph: 1-2, 2-3, 3-4, 4-1, 1-3
    # Independent sets: {1,3} not valid (edge 1-3), {2,4} valid (size 2)
    dut.num_nodes.value = 4
    dut.num_edges.value = 5
    dut.edge_a[0].value = 0  # 1-2
    dut.edge_b[0].value = 1
    dut.edge_a[1].value = 1  # 2-3
    dut.edge_b[1].value = 2
    dut.edge_a[2].value = 2  # 3-4
    dut.edge_b[2].value = 3
    dut.edge_a[3].value = 3  # 4-1
    dut.edge_b[3].value = 0
    dut.edge_a[4].value = 0  # 1-3
    dut.edge_b[4].value = 2
    for i in range(5, 8):
        dut.edge_a[i].value = 0
        dut.edge_b[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(260):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 2, f"Test 2 failed: expected 2, got {dut.result.value}"
    print(f"Test 2 PASSED: 4-node graph, 5 edges -> MIS = {dut.result.value}")
    
    await RisingEdge(dut.clk)
    await Timer(5, units='ns')
    
    # Test case 3: 3 nodes, 3 edges (complete graph K3) => MIS = 1
    dut.num_nodes.value = 3
    dut.num_edges.value = 3
    dut.edge_a[0].value = 0  # 1-2
    dut.edge_b[0].value = 1
    dut.edge_a[1].value = 1  # 2-3
    dut.edge_b[1].value = 2
    dut.edge_a[2].value = 2  # 3-1
    dut.edge_b[2].value = 0
    for i in range(3, 8):
        dut.edge_a[i].value = 0
        dut.edge_b[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(260):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 1, f"Test 3 failed: expected 1, got {dut.result.value}"
    print(f"Test 3 PASSED: K3 complete graph -> MIS = {dut.result.value}")
    
    await RisingEdge(dut.clk)
    await Timer(5, units='ns')
    
    # Test case 4: 5 nodes, 4 edges (path 1-2-3-4-5) => MIS = 3
    dut.num_nodes.value = 5
    dut.num_edges.value = 4
    dut.edge_a[0].value = 0  # 1-2
    dut.edge_b[0].value = 1
    dut.edge_a[1].value = 1  # 2-3
    dut.edge_b[1].value = 2
    dut.edge_a[2].value = 2  # 3-4
    dut.edge_b[2].value = 3
    dut.edge_a[3].value = 3  # 4-5
    dut.edge_b[3].value = 4
    for i in range(4, 8):
        dut.edge_a[i].value = 0
        dut.edge_b[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(260):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 3, f"Test 4 failed: expected 3, got {dut.result.value}"
    print(f"Test 4 PASSED: 5-node path -> MIS = {dut.result.value}")
    
    await RisingEdge(dut.clk)
    await Timer(5, units='ns')
    
    # Test case 5: 6 nodes, 6 edges (triangle + 3 isolated nodes conceptually)
    # Actually: 1-2, 2-3, 3-1, then 4-5, 5-6, 6-4 (two triangles) => MIS = 2
    dut.num_nodes.value = 6
    dut.num_edges.value = 6
    dut.edge_a[0].value = 0  # Triangle 1: 1-2
    dut.edge_b[0].value = 1
    dut.edge_a[1].value = 1  # 2-3
    dut.edge_b[1].value = 2
    dut.edge_a[2].value = 2  # 3-1
    dut.edge_b[2].value = 0
    dut.edge_a[3].value = 3  # Triangle 2: 4-5
    dut.edge_b[3].value = 4
    dut.edge_a[4].value = 4  # 5-6
    dut.edge_b[4].value = 5
    dut.edge_a[5].value = 5  # 6-4
    dut.edge_b[5].value = 3
    for i in range(6, 8):
        dut.edge_a[i].value = 0
        dut.edge_b[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(260):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    # Each triangle contributes 1, so MIS should be 2
    assert dut.result.value == 2, f"Test 5 failed: expected 2, got {dut.result.value}"
    print(f"Test 5 PASSED: Two triangles -> MIS = {dut.result.value}")
    
    print("
=== SUMMARY: 5/5 tests passed ===")