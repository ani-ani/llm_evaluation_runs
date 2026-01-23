import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_market_sharing(dut):
    """Test market sharing assignment with adapted test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 5 cities, 6 edges (should work)
    dut._log.info("Test Case 1: 5 cities, 6 edges")
    dut.num_vertices.value = 5
    dut.num_edges.value = 6
    
    # Edges: (1,2), (2,3), (3,1), (3,4), (1,4), (4,5)
    # Vertex indices are 0-based in HDL, so subtract 1
    edge_src_vals = [0, 1, 2, 2, 0, 3]  # 1-1,2-2,3-3,3-4,1-4,4-5
    edge_dst_vals = [1, 2, 0, 3, 3, 4]
    
    # Pack into bit vectors
    dut.edge_src.value = 0
    dut.edge_dst.value = 0
    for i in range(6):
        dut.edge_src.value |= (edge_src_vals[i] << (i*2))
        dut.edge_dst.value |= (edge_dst_vals[i] << (i*2))
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Test case 1 timed out")
    
    if dut.valid.value == 1:
        dut._log.info("Test case 1: Valid solution found")
        # Extract assignments
        assignments = []
        for i in range(6):
            assign = (dut.assignment.value >> (i*2)) & 0x3
            assignments.append(assign)
        dut._log.info(f"Assignments: {assignments}")
        
        # Verify constraints
        vertex_chains = {i: {'chain1': 0, 'chain2': 0} for i in range(5)}
        for i, (u, v) in enumerate(zip(edge_src_vals, edge_dst_vals)):
            if assignments[i] == 1:
                vertex_chains[u]['chain1'] += 1
                vertex_chains[v]['chain1'] += 1
            elif assignments[i] == 2:
                vertex_chains[u]['chain2'] += 1
                vertex_chains[v]['chain2'] += 1
        
        for v in range(5):
            deg = len([i for i, (u, w) in enumerate(zip(edge_src_vals, edge_dst_vals)) if u == v or w == v])
            if deg >= 2:
                if vertex_chains[v]['chain1'] == 0 or vertex_chains[v]['chain2'] == 0:
                    raise TestFailure(f"Vertex {v} (deg={deg}) missing chain: chain1={vertex_chains[v]['chain1']}, chain2={vertex_chains[v]['chain2']}")
    else:
        raise TestFailure("Test case 1: No valid solution found")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: 7 cities, 7 edges (two triangles - impossible)
    dut._log.info("Test Case 2: 7 cities, 7 edges (impossible)")
    dut.num_vertices.value = 7
    dut.num_edges.value = 7
    
    # Edges: (1,2), (2,3), (3,1), (4,5), (5,6), (6,7), (7,4)
    edge_src_vals = [0, 1, 2, 3, 4, 5, 6]
    edge_dst_vals = [1, 2, 0, 4, 5, 6, 3]
    
    dut.edge_src.value = 0
    dut.edge_dst.value = 0
    for i in range(7):
        dut.edge_src.value |= (edge_src_vals[i] << (i*2))
        dut.edge_dst.value |= (edge_dst_vals[i] << (i*2))
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Test case 2 timed out")
    
    if dut.valid.value == 0:
        dut._log.info("Test case 2: Correctly identified as impossible")
    else:
        raise TestFailure("Test case 2: Should be impossible but found solution")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 3: 5 cities, 4 edges (star graph from 1 to others)
    # Scaled down version - original had 77777 cities, 4 edges
    dut._log.info("Test Case 3: Star graph (5 cities, 4 edges)")
    dut.num_vertices.value = 5
    dut.num_edges.value = 4
    
    # Edges: (1,2), (1,3), (1,4), (1,5)
    edge_src_vals = [0, 0, 0, 0]
    edge_dst_vals = [1, 2, 3, 4]
    
    dut.edge_src.value = 0
    dut.edge_dst.value = 0
    for i in range(4):
        dut.edge_src.value |= (edge_src_vals[i] << (i*2))
        dut.edge_dst.value |= (edge_dst_vals[i] << (i*2))
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Test case 3 timed out")
    
    if dut.valid.value == 1:
        dut._log.info("Test case 3: Valid solution found")
        assignments = []
        for i in range(4):
            assign = (dut.assignment.value >> (i*2)) & 0x3
            assignments.append(assign)
        dut._log.info(f"Assignments: {assignments}")
        
        # Verify: vertex 0 (city 1) has degree 4, must have both chains
        # Vertices 1-4 (cities 2-5) have degree 1, no constraints
        vertex0_chain1 = sum(1 for a in assignments if a == 1)
        vertex0_chain2 = sum(1 for a in assignments if a == 2)
        if vertex0_chain1 == 0 or vertex0_chain2 == 0:
            raise TestFailure(f"Star center must have both chains: chain1={vertex0_chain1}, chain2={vertex0_chain2}")
    else:
        raise TestFailure("Test case 3: No valid solution found")
    
    dut._log.info("All tests completed")
    
    # Summary
    passed = 3
    total = 3
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")