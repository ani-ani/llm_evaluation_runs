import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_spanning_tree_check(dut):
    """Test spanning tree check module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.edge_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Sample Input (3 nodes, 3 edges, k=2) -> Should be 1
    # Edges: B 1-2, B 2-3, R 3-1
    # min_blue: Use Red (R 3-1), then need Blue for remaining -> min_blue = 1
    # max_blue: Use Blue (B 1-2, B 2-3) -> max_blue = 2
    # k=2 is in range [1,2] -> result = 1
    
    dut.n.value = 3
    dut.k.value = 2
    dut.m.value = 3
    await RisingEdge(dut.clk)
    
    # Load edges
    edges = [
        (1, 1, 2), # Blue: 1-2 (0-indexed: 0-1)
        (1, 2, 3), # Blue: 2-3 (0-indexed: 1-2)
        (0, 3, 1)  # Red: 3-1 (0-indexed: 2-0)
    ]
    
    for i, (color, u, v) in enumerate(edges):
        dut.edge_index.value = i
        dut.node_u.value = u - 1
        dut.node_v.value = v - 1
        dut.edge_color.value = color
        dut.edge_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.edge_valid.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (poll done signal)
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 1: Timeout waiting for done signal")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 1: Expected 1, got {int(dut.result.value)}")
    print("Test 1 passed: 3 nodes, k=2 -> result=1")
    
    # Wait a few cycles before next test
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test case 2: 2 nodes, 1 edge (Red), k=1 -> Should be 0
    # Only one spanning tree possible with 0 blue edges
    # k=1 > max_blue=0 -> result = 0
    
    dut.n.value = 2
    dut.k.value = 1
    dut.m.value = 1
    await RisingEdge(dut.clk)
    
    # Load 1 edge: Red 1-2
    dut.edge_index.value = 0
    dut.node_u.value = 0
    dut.node_v.value = 1
    dut.edge_color.value = 0 # Red
    dut.edge_valid.value = 1
    await RisingEdge(dut.clk)
    dut.edge_valid.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 2: Timeout")
    
    if dut.result.value != 0:
        raise TestFailure(f"Test 2: Expected 0, got {int(dut.result.value)}")
    print("Test 2 passed: 2 nodes, 1 Red edge, k=1 -> result=0")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test case 3: 4 nodes, mixed edges, k=1
    # Edges: R 1-2, R 2-3, B 3-4, B 4-1, B 1-3
    # min_blue: R 1-2, R 2-3, need 1 more to connect 4 -> min_blue=1 (B 3-4 or B 4-1)
    # max_blue: B 1-3, B 3-4, B 4-1 -> connects 1,3,4; need 1 more for 2 -> max_blue=2 (R 1-2 or R 2-3)
    # k=1 in [1,2] -> result=1
    
    dut.n.value = 4
    dut.k.value = 1
    dut.m.value = 5
    await RisingEdge(dut.clk)
    
    edges3 = [
        (0, 1, 2), # R 1-2
        (0, 2, 3), # R 2-3
        (1, 3, 4), # B 3-4
        (1, 4, 1), # B 4-1
        (1, 1, 3)  # B 1-3
    ]
    
    for i, (color, u, v) in enumerate(edges3):
        dut.edge_index.value = i
        dut.node_u.value = u - 1
        dut.node_v.value = v - 1
        dut.edge_color.value = color
        dut.edge_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.edge_valid.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 3: Timeout")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 3: Expected 1, got {int(dut.result.value)}")
    print("Test 3 passed: 4 nodes, k=1 -> result=1")
    
    # Test case 4: 2 nodes, 1 edge (Blue), k=0
    # Max/min blue = 1. k=0 < min_blue -> result=0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    dut.n.value = 2
    dut.k.value = 0
    dut.m.value = 1
    await RisingEdge(dut.clk)
    
    dut.edge_index.value = 0
    dut.node_u.value = 0
    dut.node_v.value = 1
    dut.edge_color.value = 1 # Blue
    dut.edge_valid.value = 1
    await RisingEdge(dut.clk)
    dut.edge_valid.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 4: Timeout")
    
    if dut.result.value != 0:
        raise TestFailure(f"Test 4: Expected 0, got {int(dut.result.value)}")
    print("Test 4 passed: 2 nodes, 1 Blue edge, k=0 -> result=0")
    
    print("All 4 tests passed!")
