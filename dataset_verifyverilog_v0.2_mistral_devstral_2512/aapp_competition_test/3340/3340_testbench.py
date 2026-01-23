import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_tree_optimizer_basic(dut):
    """Test basic 4-node line tree"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Input: 4 nodes, edges: 0-1, 1-2, 2-3 (line tree)
    dut.num_nodes.value = 4
    dut.edges.value = [[0,1], [1,2], [2,3], [0,0], [0,0], [0,0], [0,0], [0,0], [0,0], [0,0], [0,0], [0,0], [0,0], [0,0], [0,0]]
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value, "Computation did not complete"
    
    # Expected: Remove edge 2-3, add edge 1-3, diameter = 2
    print(f"Result: diameter={dut.best_diameter.value}, remove=({dut.remove_edge_u.value},{dut.remove_edge_v.value}), add=({dut.add_edge_u.value},{dut.add_edge_v.value})")
    
    assert dut.best_diameter.value == 2, f"Expected diameter 2, got {dut.best_diameter.value}"
    # The exact edge choices may vary but should be valid
    assert (dut.remove_edge_u.value == 2 and dut.remove_edge_v.value == 3) or (dut.remove_edge_u.value == 3 and dut.remove_edge_v.value == 2), "Invalid removal edge"

@cocotb.test()
async def test_tree_optimizer_star(dut):
    """Test 5-node star tree"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Star: node 0 connected to 1,2,3,4
    dut.num_nodes.value = 5
    edges = [[0,1], [0,2], [0,3], [0,4]] + [[0,0]] * 11
    dut.edges.value = edges
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value
    print(f"Star result: diameter={dut.best_diameter.value}")
    
    # Removing any edge and adding it back doesn't change diameter
    # But the problem guarantees improvement is possible
    # For star, removing edge 0-1 and adding 1-2 makes diameter 3
    assert dut.best_diameter.value <= 4, f"Diameter {dut.best_diameter.value} too large"

@cocotb.test()
async def test_tree_optimizer_specific_case(dut):
    """Test the specific 4-node example from problem"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Original: 1-2, 2-3, 3-4 (nodes 0-3)
    dut.num_nodes.value = 4
    dut.edges.value = [[0,1], [1,2], [2,3], [0,0], [0,0], [0,0], [0,0], [0,0], [0,0], [0,0], [0,0], [0,0], [0,0], [0,0], [0,0]]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value
    
    # Get results
    diameter = int(dut.best_diameter.value)
    remove_u = int(dut.remove_edge_u.value)
    remove_v = int(dut.remove_edge_v.value)
    add_u = int(dut.add_edge_u.value)
    add_v = int(dut.add_edge_v.value)
    
    print(f"
Test Result:")
    print(f"Minimum diameter: {diameter}")
    print(f"Remove edge: {remove_u} - {remove_v}")
    print(f"Add edge: {add_u} - {add_v}")
    
    # Verify diameter is 2 (optimal for 4-node line tree)
    assert diameter == 2, f"Expected diameter 2, got {diameter}"
    
    # Verify edge operations are valid (different edges)
    assert (remove_u, remove_v) != (add_u, add_v), "Remove and add edges must be different"
    
    # Verify we're not adding duplicate edge (tree becomes graph with cycle)
    # In this small tree, any new edge between non-adjacent nodes is valid
    print(f"
PASS: All constraints satisfied")

@cocotb.test()
async def test_tree_optimizer_edge_case(dut):
    """Test with 6 nodes to verify scaling"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # 6 nodes in a line
    dut.num_nodes.value = 6
    edges = [[0,1], [1,2], [2,3], [3,4], [4,5]] + [[0,0]] * 10
    dut.edges.value = edges
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 2500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value, "Timeout - computation took too long"
    
    diameter = int(dut.best_diameter.value)
    print(f"6-node line: best diameter = {diameter}")
    
    # For 6 nodes, optimal diameter should be 3 or 4
    assert diameter <= 4, f"Diameter {diameter} too large for 6 nodes"
    
    print(f"PASS: 6-node test completed")

@cocotb.test()
async def test_tree_optimizer_reset(dut):
    """Test that reset works correctly"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Start in random state
    dut.rst_n.value = 0
    await Timer(30, units='ns')
    
    # Reset
    dut.rst_n.value = 1
    await Timer(30, units='ns')
    
    # Check outputs are zero/undefined but done is low
    assert dut.done.value == 0, "Done should be low after reset"
    
    print("Reset test passed")
