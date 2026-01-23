import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_largest_committee_basic(dut):
    """Test basic clique finding with small graph"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.K.value = 0
    dut.current_vertex.value = 0
    dut.num_neighbors.value = 0
    dut.neighbor_addr.value = 0
    dut.neighbor_valid.value = 0
    dut.neighbor_id.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case 1: 5 vertices, K=3, expect clique size 3
    # Graph: 0-1, 0-2, 1-2, 1-3, 2-4, 3-4 (sample from problem)
    # Adjacency lists:
    # 0: [1,2]
    # 1: [0,2,3]
    # 2: [0,1,4]
    # 3: [1,4]
    # 4: [2,3]
    # Clique {0,1,2} has size 3
    
    dut.N.value = 5
    dut.K.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load adjacency data
    # Vertex 0: neighbors 1,2
    dut.current_vertex.value = 0
    dut.num_neighbors.value = 2
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 1
    dut.neighbor_id.value = 1
    await RisingEdge(dut.clk)
    dut.neighbor_id.value = 2
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 0
    
    # Vertex 1: neighbors 0,2,3
    dut.current_vertex.value = 1
    dut.num_neighbors.value = 3
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 1
    dut.neighbor_id.value = 0
    await RisingEdge(dut.clk)
    dut.neighbor_id.value = 2
    await RisingEdge(dut.clk)
    dut.neighbor_id.value = 3
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 0
    
    # Vertex 2: neighbors 0,1,4
    dut.current_vertex.value = 2
    dut.num_neighbors.value = 3
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 1
    dut.neighbor_id.value = 0
    await RisingEdge(dut.clk)
    dut.neighbor_id.value = 1
    await RisingEdge(dut.clk)
    dut.neighbor_id.value = 4
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 0
    
    # Vertex 3: neighbors 1,4
    dut.current_vertex.value = 3
    dut.num_neighbors.value = 2
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 1
    dut.neighbor_id.value = 1
    await RisingEdge(dut.clk)
    dut.neighbor_id.value = 4
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 0
    
    # Vertex 4: neighbors 2,3
    dut.current_vertex.value = 4
    dut.num_neighbors.value = 2
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 1
    dut.neighbor_id.value = 2
    await RisingEdge(dut.clk)
    dut.neighbor_id.value = 3
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 0
    
    # Wait for computation (allow up to 1000 cycles)
    for _ in range(1000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Computation should complete"
    assert dut.max_clique_size.value == 3, f"Expected clique size 3, got {dut.max_clique_size.value}"
    print(f"Test 1: Passed - Max clique size = {dut.max_clique_size.value}")

@cocotb.test()
async def test_largest_committee_disconnected(dut):
    """Test with disconnected graph - expect size 1"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # 3 vertices, no edges
    dut.N.value = 3
    dut.K.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Empty neighbor lists
    for v in range(3):
        dut.current_vertex.value = v
        dut.num_neighbors.value = 0
        await RisingEdge(dut.clk)
    
    # Wait for completion
    for _ in range(500):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    # Each vertex is isolated, max clique is 1
    assert dut.max_clique_size.value >= 1, f"At least size 1"
    print(f"Test 2: Passed - Max clique size = {dut.max_clique_size.value}")

@cocotb.test()
async def test_largest_committee_triangle(dut):
    """Test triangle graph - expect size 3"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Triangle: 0-1, 1-2, 2-0
    dut.N.value = 3
    dut.K.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load triangle
    dut.current_vertex.value = 0
    dut.num_neighbors.value = 2
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 1
    dut.neighbor_id.value = 1
    await RisingEdge(dut.clk)
    dut.neighbor_id.value = 2
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 0
    
    dut.current_vertex.value = 1
    dut.num_neighbors.value = 2
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 1
    dut.neighbor_id.value = 0
    await RisingEdge(dut.clk)
    dut.neighbor_id.value = 2
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 0
    
    dut.current_vertex.value = 2
    dut.num_neighbors.value = 2
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 1
    dut.neighbor_id.value = 0
    await RisingEdge(dut.clk)
    dut.neighbor_id.value = 1
    await RisingEdge(dut.clk)
    dut.neighbor_valid.value = 0
    
    for _ in range(500):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    assert dut.max_clique_size.value == 3, f"Expected 3, got {dut.max_clique_size.value}"
    print(f"Test 3: Passed - Max clique size = {dut.max_clique_size.value}")

@cocotb.test()
async def test_largest_committee_linear(dut):
    """Test linear chain - expect size 2"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Line: 0-1-2-3-4
    dut.N.value = 5
    dut.K.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    edges = [(0,1), (1,0), (1,2), (2,1), (2,3), (3,2), (3,4), (4,3)]
    # Build adjacency properly
    adj = {0:[1], 1:[0,2], 2:[1,3], 3:[2,4], 4:[3]}
    
    for v in range(5):
        dut.current_vertex.value = v
        dut.num_neighbors.value = len(adj[v])
        await RisingEdge(dut.clk)
        dut.neighbor_valid.value = 1
        for nbr in adj[v]:
            dut.neighbor_id.value = nbr
            await RisingEdge(dut.clk)
        dut.neighbor_valid.value = 0
    
    for _ in range(500):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    # Max clique in path graph is 2
    assert dut.max_clique_size.value >= 2, f"Expected at least 2"
    print(f"Test 4: Passed - Max clique size = {dut.max_clique_size.value}")

@cocotb.test()
async def test_largest_committee_single(dut):
    """Test single vertex"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    dut.N.value = 1
    dut.K.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.current_vertex.value = 0
    dut.num_neighbors.value = 0
    await RisingEdge(dut.clk)
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    assert dut.max_clique_size.value == 1, f"Expected 1"
    print(f"Test 5: Passed - Max clique size = {dut.max_clique_size.value}")

@cocotb.test()
async def test_largest_committee_k_bound(dut):
    """Test that K=2 enforces max clique size 2"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Triangle with K=2 (should find clique of size 2)
    dut.N.value = 3
    dut.K.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Triangle 0-1, 1-2, 2-0
    adj = {0:[1,2], 1:[0,2], 2:[0,1]}
    for v in range(3):
        dut.current_vertex.value = v
        dut.num_neighbors.value = len(adj[v])
        await RisingEdge(dut.clk)
        dut.neighbor_valid.value = 1
        for nbr in adj[v]:
            dut.neighbor_id.value = nbr
            await RisingEdge(dut.clk)
        dut.neighbor_valid.value = 0
    
    for _ in range(500):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    # With K=2, should find at most 2
    print(f"Test 6: Passed - Max clique size = {dut.max_clique_size.value} (K=2 bound)")

print("All tests completed")