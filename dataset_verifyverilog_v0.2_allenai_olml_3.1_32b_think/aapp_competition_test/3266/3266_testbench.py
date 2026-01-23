import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
import random

@cocotb.test()
async def test_max_flow_solver(dut):
    """Test max flow solver with multiple test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.source.value = 0
    dut.sink.value = 0
    dut.num_nodes.value = 0
    dut.edge_count.value = 0
    for i in range(4):
        for j in range(4):
            dut.capacity[i][j].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def run_test(test_name, n, s, t, edges, expected_flow, expected_edges):
        print(f"
=== Test: {test_name} ===")
        
        # Initialize capacity matrix
        capacity_matrix = [[0]*4 for _ in range(4)]
        for u, v, c in edges:
            capacity_matrix[u][v] = c
        
        for i in range(4):
            for j in range(4):
                dut.capacity[i][j].value = capacity_matrix[i][j]
        
        dut.source.value = s
        dut.sink.value = t
        dut.num_nodes.value = n
        dut.edge_count.value = len(edges)
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion with timeout
        timeout = 10000
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            print("TIMEOUT - computation took too long")
            assert False, "Timeout"
        
        # Read results
        result_flow = int(dut.max_flow.value)
        print(f"Result flow: {result_flow}, Expected: {expected_flow}")
        assert result_flow == expected_flow, f"Flow mismatch: got {result_flow}, expected {expected_flow}"
        
        # Collect output edges
        output_edges = []
        out_valid_prev = 0
        
        # Output happens over multiple cycles after done
        for _ in range(20):
            await RisingEdge(dut.clk)
            if int(dut.out_valid.value) == 1:
                u = int(dut.out_u.value)
                v = int(dut.out_v.value)
                flow = int(dut.out_flow.value)
                if flow > 0:
                    output_edges.append((u, v, flow))
            if out_valid_prev == 1 and int(dut.out_valid.value) == 0:
                break
            out_valid_prev = int(dut.out_valid.value)
        
        print(f"Output edges: {output_edges}")
        print(f"Expected edges: {expected_edges}")
        
        assert len(output_edges) == len(expected_edges), f"Edge count mismatch: {len(output_edges)} vs {len(expected_edges)}"
        
        # Sort for comparison
        output_edges.sort()
        expected_edges.sort()
        
        for i, (ou, ov, of) in enumerate(output_edges):
            eu, ev, ef = expected_edges[i]
            assert ou == eu and ov == ev and of == ef, f"Edge {i} mismatch: got ({ou},{ov},{of}), expected ({eu},{ev},{ef})"
        
        print(f"PASSED")
    
    # Test 1: Sample Input 1
    # 4 nodes, source=0, sink=3
    # Edges: 0->1(10), 1->2(1), 1->3(1), 0->2(1), 2->3(10)
    # Expected max flow: 3
    edges1 = [(0,1,10), (1,2,1), (1,3,1), (0,2,1), (2,3,10)]
    expected_edges1 = [(0,1,2), (0,2,1), (1,2,1), (1,3,1), (2,3,2)]
    await run_test("Sample1", 4, 0, 3, edges1, 3, expected_edges1)
    
    # Test 2: Sample Input 2
    # 2 nodes, source=0, sink=1, single edge capacity 100000
    # Expected max flow: 100000
    edges2 = [(0,1,100000)]
    expected_edges2 = [(0,1,100000)]
    await run_test("Sample2", 2, 0, 1, edges2, 100000, expected_edges2)
    
    # Test 3: Sample Input 3 (reversed direction, no path from 1 to 0)
    # 2 nodes, source=1, sink=0, edge 0->1 only
    # Expected max flow: 0
    edges3 = [(0,1,100000)]
    expected_edges3 = []
    await run_test("Sample3", 2, 1, 0, edges3, 0, expected_edges3)
    
    # Test 4: Diamond graph
    # 4 nodes: 0->1(5), 0->2(3), 1->3(4), 2->3(4), 1->2(1)
    # Expected max flow: 7 (path 0-1-3: 4, 0-2-3: 3)
    edges4 = [(0,1,5), (0,2,3), (1,3,4), (2,3,4), (1,2,1)]
    expected_edges4 = [(0,1,4), (0,2,3), (1,2,1), (1,3,3), (2,3,4)]
    await run_test("Diamond", 4, 0, 3, edges4, 7, expected_edges4)
    
    # Test 5: Parallel paths
    # 3 nodes: 0->1(2), 0->2(3), 1->2(1), 1->2(1)
    # Expected: 5 (but limited by back edge)
    edges5 = [(0,1,2), (0,2,3), (1,2,1)]
    expected_edges5 = [(0,1,2), (0,2,3), (1,2,1)]
    await run_test("Parallel", 3, 0, 2, edges5, 5, expected_edges5)
    
    print("
=== ALL TESTS PASSED ===")

@cocotb.test()
async def test_max_flow_edge_cases(dut):
    """Test edge cases and corner conditions"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: Source and sink same (should return 0 flow)
    # Though problem states s != t, we verify behavior
    print("
=== Test: Self-loop prevention ===")
    for i in range(4):
        for j in range(4):
            dut.capacity[i][j].value = 10
    dut.source.value = 1
    dut.sink.value = 1
    dut.num_nodes.value = 4
    dut.edge_count.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 10000
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    # Should complete quickly with 0 flow or no valid path
    flow = int(dut.max_flow.value)
    print(f"Same node flow: {flow}")
    # The module might produce 0 or handle this as no path
    
    # Test: Minimum capacity edges
    print("
=== Test: Minimum capacities ===")
    for i in range(4):
        for j in range(4):
            dut.capacity[i][j].value = 0
    dut.capacity[0][1].value = 1
    dut.capacity[1][2].value = 1
    dut.capacity[2][3].value = 1
    
    dut.source.value = 0
    dut.sink.value = 3
    dut.num_nodes.value = 4
    dut.edge_count.value = 3
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 5000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    flow = int(dut.max_flow.value)
    print(f"Min capacity flow: {flow}")
    assert flow == 1, f"Expected 1, got {flow}"
    
    # Test: Multiple disjoint paths
    print("
=== Test: Disjoint paths ===")
    for i in range(4):
        for j in range(4):
            dut.capacity[i][j].value = 0
    dut.capacity[0][1].value = 5
    dut.capacity[0][2].value = 3
    dut.capacity[1][3].value = 5
    dut.capacity[2][3].value = 3
    
    dut.source.value = 0
    dut.sink.value = 3
    dut.num_nodes.value = 4
    dut.edge_count.value = 4
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 5000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    flow = int(dut.max_flow.value)
    print(f"Disjoint paths flow: {flow}")
    assert flow == 8, f"Expected 8, got {flow}"
    
    # Test: Zero flow (no path)
    print("
=== Test: No path ===")
    for i in range(4):
        for j in range(4):
            dut.capacity[i][j].value = 0
    dut.capacity[0][1].value = 5
    dut.capacity[2][3].value = 5
    
    dut.source.value = 0
    dut.sink.value = 3
    dut.num_nodes.value = 4
    dut.edge_count.value = 2
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 5000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    flow = int(dut.max_flow.value)
    print(f"No path flow: {flow}")
    assert flow == 0, f"Expected 0, got {flow}"
    
    print("
=== ALL EDGE CASE TESTS PASSED ===")