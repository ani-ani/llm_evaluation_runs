import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_shortest_path_edge_counter(dut):
    """Test shortest path edge counter"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.node_count.value = 0
    dut.edge_count.value = 0
    for i in range(16):
        dut.edge_src[i].value = 0
        dut.edge_dst[i].value = 0
        dut.edge_weight[i].value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: Simple chain 1->2->3->4
    dut._log.info("Test 1: Chain 1->2->3->4")
    dut.node_count.value = 4
    dut.edge_count.value = 3
    dut.edge_src[0].value = 0  # 1->2
    dut.edge_dst[0].value = 1
    dut.edge_weight[0].value = 5
    dut.edge_src[1].value = 1  # 2->3
    dut.edge_dst[1].value = 2
    dut.edge_weight[1].value = 5
    dut.edge_src[2].value = 2  # 3->4
    dut.edge_dst[2].value = 3
    dut.edge_weight[2].value = 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 300 cycles)
    for _ in range(350):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    # Expected: edge0=3, edge1=4, edge2=3
    assert dut.edge_usage[0].value == 3, f"Edge 0: expected 3, got {dut.edge_usage[0].value}"
    assert dut.edge_usage[1].value == 4, f"Edge 1: expected 4, got {dut.edge_usage[1].value}"
    assert dut.edge_usage[2].value == 3, f"Edge 2: expected 3, got {dut.edge_usage[2].value}"
    dut._log.info("Test 1 passed: [3, 4, 3]")
    
    await RisingEdge(dut.clk)
    
    # Test 2: Diamond with shortcut
    dut._log.info("Test 2: Diamond with shortcut")
    dut.node_count.value = 4
    dut.edge_count.value = 4
    # 1->2, 2->3, 3->4, 1->4
    dut.edge_src[0].value = 0
    dut.edge_dst[0].value = 1
    dut.edge_weight[0].value = 5
    dut.edge_src[1].value = 1
    dut.edge_dst[1].value = 2
    dut.edge_weight[1].value = 5
    dut.edge_src[2].value = 2
    dut.edge_dst[2].value = 3
    dut.edge_weight[2].value = 5
    dut.edge_src[3].value = 0
    dut.edge_dst[3].value = 3
    dut.edge_weight[3].value = 8
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(350):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    # Expected: edge0=2, edge1=3, edge2=2, edge3=1
    assert dut.edge_usage[0].value == 2, f"Edge 0: expected 2, got {dut.edge_usage[0].value}"
    assert dut.edge_usage[1].value == 3, f"Edge 1: expected 3, got {dut.edge_usage[1].value}"
    assert dut.edge_usage[2].value == 2, f"Edge 2: expected 2, got {dut.edge_usage[2].value}"
    assert dut.edge_usage[3].value == 1, f"Edge 3: expected 1, got {dut.edge_usage[3].value}"
    dut._log.info("Test 2 passed: [2, 3, 2, 1]")
    
    await RisingEdge(dut.clk)
    
    # Test 3: Parallel edges and complex paths
    dut._log.info("Test 3: Complex graph")
    dut.node_count.value = 5
    dut.edge_count.value = 8
    # 1->2(20), 1->3(2), 2->3(2), 4->2(3), 4->2(3) [duplicate], 3->4(5), 4->3(5), 5->4(20)
    edges = [
        (0,1,20), (0,2,2), (1,2,2), (3,1,3), (3,1,3),
        (2,3,5), (3,2,5), (4,3,20)
    ]
    for i, (src, dst, w) in enumerate(edges):
        dut.edge_src[i].value = src
        dut.edge_dst[i].value = dst
        dut.edge_weight[i].value = w
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(350):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    # Expected: [0, 4, 6, 6, 6, 7, 2, 6]
    expected = [0, 4, 6, 6, 6, 7, 2, 6]
    for i in range(8):
        assert dut.edge_usage[i].value == expected[i], f"Edge {i}: expected {expected[i]}, got {dut.edge_usage[i].value}"
    dut._log.info("Test 3 passed: [0, 4, 6, 6, 6, 7, 2, 6]")
    
    dut._log.info("All 3/3 tests passed!")