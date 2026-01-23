import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_min_trucks_solver(dut):
    """Test the min_trucks_solver module"""
    
    # Create clock and start it
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to apply inputs and wait for result
    async def run_test(num_nodes, num_edges, num_clients, client_locs, edges):
        # Set inputs
        dut.num_nodes.value = num_nodes
        dut.num_edges.value = num_edges
        dut.num_clients.value = num_clients
        
        for i in range(4):
            dut.client_locs[i].value = client_locs[i] if i < len(client_locs) else 0
        
        for i in range(8):
            if i < len(edges):
                dut.edge_u[i].value = edges[i][0]
                dut.edge_v[i].value = edges[i][1]
                dut.edge_w[i].value = edges[i][2]
            else:
                dut.edge_u[i].value = 0
                dut.edge_v[i].value = 0
                dut.edge_w[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        return int(dut.min_trucks.value)
    
    # Test Case 1: Sample 1 adapted (2 trucks expected)
    # Original: 4 nodes, 5 edges, 3 clients
    # Warehouse 0, clients at 1, 2, 3
    # Edges: 0->1(1), 0->3(1), 0->2(2), 1->2(1), 3->2(1)
    # Shortest paths: T1=1, T2=2, T3=1
    # DAG: 0->1, 0->3, 1->2, 3->2
    # Min path cover: 2 trucks (0->1->2 and 0->3)
    result1 = await run_test(
        num_nodes=4,
        num_edges=5,
        num_clients=3,
        client_locs=[1, 2, 3],
        edges=[
            (0, 1, 1),
            (0, 3, 1),
            (0, 2, 2),
            (1, 2, 1),
            (3, 2, 1)
        ]
    )
    
    dut._log.info(f"Test 1 Result: {result1}, Expected: 2")
    assert result1 == 2, f"Test 1 failed: got {result1}, expected 2"
    
    # Test Case 2: Sample 2 adapted (3 trucks expected)
    # Original: 4 nodes, 5 edges, 3 clients
    # All edges weight 1
    # Shortest paths: T1=1, T2=1, T3=1
    # DAG: 0->1, 0->2, 0->3, 1->2, 3->2
    # But since all T=1, clients 1,2,3 must be visited at time 1
    # Cannot use 1->2 or 3->2 to visit 2 at time 1
    # Need 3 separate trucks
    result2 = await run_test(
        num_nodes=4,
        num_edges=5,
        num_clients=3,
        client_locs=[1, 2, 3],
        edges=[
            (0, 1, 1),
            (0, 3, 1),
            (0, 2, 1),
            (1, 2, 1),
            (3, 2, 1)
        ]
    )
    
    dut._log.info(f"Test 2 Result: {result2}, Expected: 3")
    assert result2 == 3, f"Test 2 failed: got {result2}, expected 3"
    
    # Test Case 3: Simple chain (1 truck expected)
    # 3 nodes, edges: 0->1(1), 1->2(1)
    # Clients at 1 and 2
    # T1=1, T2=2
    # Path 0->1->2 covers both
    result3 = await run_test(
        num_nodes=3,
        num_edges=2,
        num_clients=2,
        client_locs=[1, 2],
        edges=[
            (0, 1, 1),
            (1, 2, 1)
        ]
    )
    
    dut._log.info(f"Test 3 Result: {result3}, Expected: 1")
    assert result3 == 1, f"Test 3 failed: got {result3}, expected 1"
    
    # Test Case 4: Parallel branches (2 trucks expected)
    # 4 nodes, edges: 0->1(1), 0->2(1), 1->3(1), 2->3(1)
    # Clients at 1, 2, 3
    # T1=1, T2=1, T3=2
    # Need 2 trucks: 0->1->3 and 0->2->3
    result4 = await run_test(
        num_nodes=4,
        num_edges=4,
        num_clients=3,
        client_locs=[1, 2, 3],
        edges=[
            (0, 1, 1),
            (0, 2, 1),
            (1, 3, 1),
            (2, 3, 1)
        ]
    )
    
    dut._log.info(f"Test 4 Result: {result4}, Expected: 2")
    assert result4 == 2, f"Test 4 failed: got {result4}, expected 2"
    
    # Test Case 5: All clients at same node (1 truck expected)
    # 3 nodes, edges: 0->1(1), 0->2(1)
    # Clients at 1, 1 (duplicates not allowed in original, so use 1 and 2 but same time)
    # Actually use: clients at 1, 2 with both T=1
    # But this needs 2 trucks. Let's use different case:
    # 2 clients at same node (if allowed) or 
    # Simpler: 2 clients, one on path to another
    # 3 nodes, 0->1(1), 1->2(1)
    # Clients at 1 and 2
    # Already tested as case 3
    # Let's do: 2 clients, different times, but can share
    result5 = await run_test(
        num_nodes=3,
        num_edges=2,
        num_clients=2,
        client_locs=[1, 2],
        edges=[
            (0, 1, 1),
            (1, 2, 1)
        ]
    )
    
    dut._log.info(f"Test 5 Result: {result5}, Expected: 1")
    assert result5 == 1, f"Test 5 failed: got {result5}, expected 1"
    
    dut._log.info("All tests passed!")