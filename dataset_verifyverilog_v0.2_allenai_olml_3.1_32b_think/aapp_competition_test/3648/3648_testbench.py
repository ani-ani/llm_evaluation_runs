import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_secure_network(dut):
    """Test the secure_network module with 2 adapted test cases."""
    # Clock generation (50MHz)
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.p.value = 0
    dut.insecure_mask.value = 0
    for i in range(28):
        dut.edge_valid[i].value = 0
        dut.edge_u[i].value = 0
        dut.edge_v[i].value = 0
        dut.edge_w[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # --- Test Case 1 (Adapted from Sample 1) ---
    # Original: 4 nodes, 1 insecure (node 1), find MST cost 6.
    # Adapted: 4 nodes (0-3), 1 insecure (node 0), edges:
    # 0-1 (w1), 0-2 (w1), 0-3 (w1), 1-2 (w2), 1-3 (w4), 2-3 (w3)
    # Valid tree: {1-2, 2-3, 1-3} connects all, insecure node 0 is isolated? 
    # Wait, insecure node must be reachable. 
    # Let's adjust: Insecure node 0 is a leaf. 
    # If we connect 0-1 (cost 1), and then 1-2 (2), 2-3 (3), 0 is leaf (degree 1). 
    # Total cost = 1 + 2 + 3 = 6.
    
    dut.n.value = 4
    dut.p.value = 1
    dut.insecure_mask.value = 0b00000001 # Node 0 insecure
    
    # Define edges (indices 0-5)
    edges_config = [
        (0, 1, 1), # 0-1
        (0, 2, 1), # 0-2
        (0, 3, 1), # 0-3
        (1, 2, 2), # 1-2
        (1, 3, 4), # 1-3
        (2, 3, 3)  # 2-3
    ]
    
    for i, (u, v, w) in enumerate(edges_config):
        dut.edge_valid[i].value = 1
        dut.edge_u[i].value = u
        dut.edge_v[i].value = v
        dut.edge_w[i].value = w
        
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (with timeout)
    cycles = 0
    while dut.done.value == 0 and cycles < 2000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert cycles < 2000, "Test 1: Timeout"
    assert dut.impossible.value == 0, "Test 1: Should be possible"
    assert dut.result.value == 6, f"Test 1: Expected 6, got {dut.result.value}"
    print(f"Test 1 Passed: Cost={dut.result.value}")
    
    # --- Reset for Test Case 2 ---
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # --- Test Case 2 (Adapted from Sample 2) ---
    # Original: 4 nodes, 2 insecure (1, 2), edges 1-2(1), 2-3(7), 3-4(5). 
    # Logic: If 1 and 2 are insecure, they must be leaves. 
    # Edge 1-2 exists. If we use it, both 1 and 2 have degree >= 1. 
    # If we connect 1-2, they are connected to each other. But they need to reach the rest.
    # If we connect 2-3, node 2 has degree 2. Invalid.
    # So we must connect 1-3 and 2-3? Edge doesn't exist.
    # Adapted: 4 nodes (0-3). Insecure (0, 1). 
    # Edges: 0-1(w1), 1-2(w7), 2-3(w5).
    # Try to form tree: 
    # Option A: {0-1, 1-2, 2-3}. Node 1 degree 2 (invalid).
    # Option B: {0-1, 2-3}. Disconnected (invalid).
    # Option C: {1-2, 2-3}. Node 1 degree 1 (valid), but node 0 isolated? 
    # If connectivity requires all nodes, node 0 is missing.
    # If we add edge 0-1, node 1 becomes degree 2 (invalid).
    # So indeed, impossible.
    
    dut.n.value = 4
    dut.p.value = 2
    dut.insecure_mask.value = 0b00000011 # Node 0 and 1 insecure
    
    # Reset all edges
    for i in range(28):
        dut.edge_valid[i].value = 0
    
    edges_config_2 = [
        (0, 1, 1), # 0-1
        (1, 2, 7), # 1-2
        (2, 3, 5)  # 2-3
    ]
    
    for i, (u, v, w) in enumerate(edges_config_2):
        dut.edge_valid[i].value = 1
        dut.edge_u[i].value = u
        dut.edge_v[i].value = v
        dut.edge_w[i].value = w
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles = 0
    while dut.done.value == 0 and cycles < 2000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert cycles < 2000, "Test 2: Timeout"
    assert dut.impossible.value == 1, "Test 2: Should be impossible"
    print(f"Test 2 Passed: Impossible flag set correctly")
    print("All tests passed!")