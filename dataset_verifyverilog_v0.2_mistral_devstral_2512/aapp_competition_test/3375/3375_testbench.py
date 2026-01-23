import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_count_unicyclic(dut):
    """Test counting of spanning unicyclic subgraphs for small graphs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.edge_addr.value = 0
    dut.edge_v1.value = 0
    dut.edge_v2.value = 0
    dut.num_vertices.value = 0
    dut.num_edges.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
Test 1: 4 vertices, 5 edges (sample)")
    # Graph: (1,2), (1,3), (2,3), (1,4), (2,4)
    # Vertices: 1-4, all connected
    # Unicyclic spanning subgraphs: 5
    # The 5 are the triangles plus one connecting edge:
    # - (1,2),(1,3),(2,3) + (1,4) [triangle 1-2-3 plus 4 to 1]
    # - (1,2),(1,3),(2,3) + (2,4) [triangle 1-2-3 plus 4 to 2]
    # - (1,2),(1,4),(2,4) + (1,3) [triangle 1-2-4 plus 3 to 1]
    # - (1,2),(1,4),(2,4) + (2,3) [triangle 1-2-4 plus 3 to 2]
    # - (1,3),(1,4),(2,4) + (2,3) [triangle 1-3-4 plus 3 to 2] - wait this is not right
    # Actually, spanning unicyclic means exactly one cycle and connects all vertices
    # For 4 vertices, need 4 edges
    # Valid: (1,2),(1,3),(2,3),(1,4), (1,2),(1,3),(2,3),(2,4), (1,2),(1,4),(2,4),(1,3), (1,2),(1,4),(2,4),(2,3), (1,3),(1,4),(2,4),(2,3)
    # But last one: vertices 1,3,4 with (1,3),(1,4) and 2,4 with (2,4), and need one more to connect, this is actually not 4 vertices
    # Let's recount: We need all 4 vertices connected with exactly 4 edges
    # With 4 vertices and 4 edges, connected => exactly one cycle
    # Choices: pick a cycle (triangle), then connect 4th vertex
    # Triangles: (1,2,3) only
    # Connect 4th vertex (4) to either 1 or 2: 2 choices
    # That's only 2... Wait, the sample says 5.
    # Oh, the graph has edges (1,2),(1,3),(2,3),(1,4),(2,4). 
    # There is NO triangle (3,4,1) or (3,4,2) because (3,4) is missing.
    # So only one triangle (1,2,3).
    # How does 5 come? Let me re-read.
    # Actually, wait. (1,2),(1,3),(2,3),(1,4) -> 1,2,3,4 connected with 4 edges -> cycle 1-2-3-1, tree to 4 (at 1). Unicyclic.
    # (1,2),(1,3),(2,3),(2,4) -> same. 2 choices.
    # (1,2),(1,4),(2,4) -> triangle 1-2-4. Plus edge (1,3). -> 1,2,3,4 connected. Unicyclic.
    # (1,2),(1,4),(2,4) -> triangle 1-2-4. Plus edge (2,3). -> 1,2,3,4 connected. Unicyclic.
    # (1,3),(1,4),(2,4) -> this is a tree (1-3, 1-4, 2-4). It has 3 edges, NOT 4. Need 4 edges.
    # (1,3),(1,4),(2,4),(2,3) -> edges (1,3),(1,4),(2,3),(2,4). Vertices 1,2,3,4. Graph: 1-3, 2-3, 1-4, 2-4. Components? 1 connected to 3,4. 2 connected to 3,4. So 1 and 2 are connected via 3 or 4. It is connected. Edges: 4. Vertices: 4. Cycle? 1-3-2-4-1. Yes, one cycle. Unicyclic.
    # Wait, (1,3),(2,3),(1,4),(2,4) is a valid set.
    # So we have:
    # 1. (1,2),(1,3),(2,3),(1,4)
    # 2. (1,2),(1,3),(2,3),(2,4)
    # 3. (1,2),(1,4),(2,4),(1,3)
    # 4. (1,2),(1,4),(2,4),(2,3)
    # 5. (1,3),(2,3),(1,4),(2,4)
    # Yes, 5 total.
    
    # Load edges
    edges1 = [(1,2), (1,3), (2,3), (1,4), (2,4)]
    for i, (v1, v2) in enumerate(edges1):
        dut.edge_addr.value = i
        dut.edge_v1.value = v1
        dut.edge_v2.value = v2
        await RisingEdge(dut.clk)
    
    dut.num_vertices.value = 4
    dut.num_edges.value = 5
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test 1 timed out")
    
    result = int(dut.result.value)
    print(f"Result: {result}, Expected: 5")
    if result != 5:
        raise TestFailure(f"Test 1 failed: got {result}, expected 5")
    
    await RisingEdge(dut.clk)
    
    # Test 2: 4 vertices, 2 edges (disconnected)
    print("
Test 2: 4 vertices, 2 edges (disconnected)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    edges2 = [(1,2), (3,4)]
    for i, (v1, v2) in enumerate(edges2):
        dut.edge_addr.value = i
        dut.edge_v1.value = v1
        dut.edge_v2.value = v2
        await RisingEdge(dut.clk)
    
    dut.num_vertices.value = 4
    dut.num_edges.value = 2
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test 2 timed out")
    
    result = int(dut.result.value)
    print(f"Result: {result}, Expected: 0")
    if result != 0:
        raise TestFailure(f"Test 2 failed: got {result}, expected 0")
    
    await RisingEdge(dut.clk)
    
    # Test 3: 3 vertices, 3 edges (triangle) - unicyclic itself
    print("
Test 3: 3 vertices, 3 edges (triangle)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    edges3 = [(1,2), (1,3), (2,3)]
    for i, (v1, v2) in enumerate(edges3):
        dut.edge_addr.value = i
        dut.edge_v1.value = v1
        dut.edge_v2.value = v2
        await RisingEdge(dut.clk)
    
    dut.num_vertices.value = 3
    dut.num_edges.value = 3
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test 3 timed out")
    
    result = int(dut.result.value)
    print(f"Result: {result}, Expected: 1")
    if result != 1:
        raise TestFailure(f"Test 3 failed: got {result}, expected 1")
    
    await RisingEdge(dut.clk)
    
    # Test 4: 4 vertices, 4 edges (4-cycle) - unicyclic
    print("
Test 4: 4 vertices, 4 edges (4-cycle)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    edges4 = [(1,2), (2,3), (3,4), (1,4)]
    for i, (v1, v2) in enumerate(edges4):
        dut.edge_addr.value = i
        dut.edge_v1.value = v1
        dut.edge_v2.value = v2
        await RisingEdge(dut.clk)
    
    dut.num_vertices.value = 4
    dut.num_edges.value = 4
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test 4 timed out")
    
    result = int(dut.result.value)
    print(f"Result: {result}, Expected: 1")
    if result != 1:
        raise TestFailure(f"Test 4 failed: got {result}, expected 1")
    
    await RisingEdge(dut.clk)
    
    # Test 5: 5 vertices, 5 edges (5-cycle)
    print("
Test 5: 5 vertices, 5 edges (5-cycle)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    edges5 = [(1,2), (2,3), (3,4), (4,5), (1,5)]
    for i, (v1, v2) in enumerate(edges5):
        dut.edge_addr.value = i
        dut.edge_v1.value = v1
        dut.edge_v2.value = v2
        await RisingEdge(dut.clk)
    
    dut.num_vertices.value = 5
    dut.num_edges.value = 5
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test 5 timed out")
    
    result = int(dut.result.value)
    print(f"Result: {result}, Expected: 1")
    if result != 1:
        raise TestFailure(f"Test 5 failed: got {result}, expected 1")
    
    print("
All tests passed!")
