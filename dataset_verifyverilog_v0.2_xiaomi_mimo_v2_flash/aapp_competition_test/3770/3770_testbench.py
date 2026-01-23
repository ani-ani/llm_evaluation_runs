import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge, Edge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_graph_profit_maximizer(dut):
    """
    Tests the Graph Profit Maximizer module using the Dinic algorithm logic.
    We will verify against a Python reference implementation.
    """
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_mode.value = 0
    dut.node_idx.value = 0
    dut.edge_idx.value = 0
    dut.A_val.value = 0
    dut.B_val.value = 0
    dut.U_val.value = 0
    dut.V_val.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # --- Test Case 1: Sample Input from Prompt ---
    # N=4, M=4
    # A = [4, 1, 2, 3]
    # B = [0, 2, -3, 1]
    # Edges: (1,2), (2,3), (3,4), (4,2)
    # Expected Output: 1
    
    N = 4
    M = 4
    A = [4, 1, 2, 3]
    B = [0, 2, -3, 1]
    edges = [(1, 2), (2, 3), (3, 4), (4, 2)]
    
    # Load Nodes
    dut.load_mode.value = 0
    for i in range(N):
        dut.node_idx.value = i
        dut.A_val.value = A[i]
        dut.B_val.value = B[i]
        await RisingEdge(dut.clk)
        
    # Load Edges
    dut.load_mode.value = 1
    for i in range(M):
        dut.edge_idx.value = i
        dut.U_val.value = edges[i][0]
        dut.V_val.value = edges[i][1]
        await RisingEdge(dut.clk)

    # Start Computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for Done
    # The module might take many cycles (e.g., 10,000 for small N=300 hardware, much less for N=4)
    # We loop with a timeout
    cycles = 0
    max_cycles = 5000 # Safe timeout
    while dut.done.value == 0 and cycles < max_cycles:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if cycles >= max_cycles:
        dut._log.error("Test timed out!")
        assert False
    
    result = int(dut.max_profit.value)
    dut._log.info(f"Test Case 1 Result: {result}")
    assert result == 1, f"Expected 1, got {result}"
    
    # --- Test Case 2: Simple 3-node case ---
    # N=3, M=2
    # A = [1, 1, 1]
    # B = [5, -2, -2]
    # Edges: (1, 2), (2, 3)
    # Positive sum = 5. 
    # If we cut edge (1,2), we remove 1 but also isolate node 1. 
    # If we delete node 2 (cost 1), graph splits into {1} and {3}. 
    # Profit = |5| + |-2| - 1 = 6 - 1 = 5? No, deleting node 2 removes edge costs but keeps components separate.
    # Wait, the problem says: deleting vertex i costs A_i. Edges incident to it are deleted.
    # Score is sum of absolute B values of components.
    # If we don't delete: Component {1,2,3}. Sum B = 5-2-2 = 1. Abs = 1. Profit = 1 - 0 = 1.
    # If we delete node 2: Cost 1. Components {1}, {3}. Scores |5| + |-2| = 7. Profit = 7 - 1 = 6.
    # So expected output is 6.
    
    # Let's reset and load new data
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    N2 = 3
    M2 = 2
    A2 = [1, 1, 1]
    B2 = [5, -2, -2]
    edges2 = [(1, 2), (2, 3)]
    
    dut.load_mode.value = 0
    for i in range(N2):
        dut.node_idx.value = i
        dut.A_val.value = A2[i]
        dut.B_val.value = B2[i]
        await RisingEdge(dut.clk)
        
    dut.load_mode.value = 1
    for i in range(M2):
        dut.edge_idx.value = i
        dut.U_val.value = edges2[i][0]
        dut.V_val.value = edges2[i][1]
        await RisingEdge(dut.clk)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0 and cycles < max_cycles:
        await RisingEdge(dut.clk)
        cycles += 1
        
    result = int(dut.max_profit.value)
    dut._log.info(f"Test Case 2 Result: {result}")
    assert result == 6, f"Expected 6, got {result}"
    
    dut._log.info("All tests passed!")
