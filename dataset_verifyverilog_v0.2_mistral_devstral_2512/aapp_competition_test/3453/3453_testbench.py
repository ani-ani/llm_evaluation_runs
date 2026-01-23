import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_danger_level_calculator(dut):
    """Test danger level calculator with small graphs"""
    
    # Helper function to compute shortest paths for verification
    def compute_danger_levels(nodes, edges):
        # nodes: list of node IDs (0-7)
        # edges: list of (u, v, weight)
        INF = 10**9
        dist = [[INF] * 8 for _ in range(8)]
        for i in range(8):
            dist[i][i] = 0
        
        for u, v, w in edges:
            if w < dist[u][v]:
                dist[u][v] = dist[v][u] = w
        
        # Floyd-Warshall
        for k in range(8):
            for i in range(8):
                for j in range(8):
                    if dist[i][k] + dist[k][j] < dist[i][j]:
                        dist[i][j] = dist[i][k] + dist[k][j]
        
        # Danger levels
        danger = [0] * 8
        for i in range(8):
            for j in range(8):
                if i != j and dist[i][j] < INF:
                    danger[i] = (danger[i] + dist[i][j]) % 1000000007
        
        return danger
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.edge_valid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Simple 5-node graph (from problem)
    # Graph: 1-2(3), 1-4(8), 2-3(12), 3-5(4), 4-5(2)
    # Convert to 0-indexed: 0-1(3), 0-3(8), 1-2(12), 2-4(4), 3-4(2)
    edges = [(0,1,3), (0,3,8), (1,2,12), (2,4,4), (3,4,2)]
    expected = [35, 39, 36, 27, 29, 0, 0, 0]
    
    # Load graph
    dut.start.value = 0
    for u, v, w in edges:
        dut.node_idx.value = u
        dut.neighbor_idx.value = v
        dut.edge_weight.value = w
        dut.edge_valid.value = 1
        await RisingEdge(dut.clk)
    dut.edge_valid.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for computation
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Timeout - computation didn't complete")
    
    # Collect results
    results = []
    for i in range(8):
        # Wait for result_valid
        timeout = 0
        while not dut.result_valid.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        if timeout >= 100:
            raise TestFailure(f"Timeout waiting for result valid for node {i}")
        
        results.append(int(dut.danger_level.value))
        await RisingEdge(dut.clk)
    
    # Verify
    for i in range(5):  # Only check first 5 nodes as others are 0
        if results[i] != expected[i]:
            raise TestFailure(f"Node {i}: expected {expected[i]}, got {results[i]}")
    
    print(f"Test 1 passed: {results[:5]}")
    
    # Test Case 2: Another graph
    # Reset and load new graph
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Graph: 0-1(8), 0-2(15), 0-3(10), 2-4(40), 2-5(3), 4-6(60)
    edges2 = [(0,1,8), (0,2,15), (0,3,10), (2,4,40), (2,5,3), (4,6,60)]
    expected2 = [221, 261, 206, 271, 326, 221, 626, 0]
    
    for u, v, w in edges2:
        dut.node_idx.value = u
        dut.neighbor_idx.value = v
        dut.edge_weight.value = w
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
        raise TestFailure("Timeout - computation didn't complete")
    
    results2 = []
    for i in range(8):
        timeout = 0
        while not dut.result_valid.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        if timeout >= 100:
            raise TestFailure(f"Timeout waiting for result valid for node {i}")
        
        results2.append(int(dut.danger_level.value))
        await RisingEdge(dut.clk)
    
    for i in range(7):  # Check first 7 nodes
        if results2[i] != expected2[i]:
            raise TestFailure(f"Node {i}: expected {expected2[i]}, got {results2[i]}")
    
    print(f"Test 2 passed: {results2[:7]}")
    
    # Test Case 3: Simple 2-node graph (edge case)
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Graph: 0-1(5)
    edges3 = [(0,1,5)]
    expected3 = [5, 5, 0, 0, 0, 0, 0, 0]
    
    for u, v, w in edges3:
        dut.node_idx.value = u
        dut.neighbor_idx.value = v
        dut.edge_weight.value = w
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
        raise TestFailure("Timeout - computation didn't complete")
    
    results3 = []
    for i in range(8):
        timeout = 0
        while not dut.result_valid.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        if timeout >= 100:
            raise TestFailure(f"Timeout waiting for result valid for node {i}")
        
        results3.append(int(dut.danger_level.value))
        await RisingEdge(dut.clk)
    
    if results3[0] != 5 or results3[1] != 5:
        raise TestFailure(f"2-node test failed: {results3[:2]}")
    
    print(f"Test 3 passed: {results3[:2]}")
    print("All 3/3 tests passed!")