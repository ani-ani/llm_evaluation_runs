import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_safe_network(dut):
    # Clock generation
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_minus_1_edges_count.value = 0
    dut.u.value = 0
    dut.v.value = 0
    dut.edge_index.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Star graph with 4 nodes (root 0, edges 0-1, 0-2, 0-3)
    # Leaves: 1, 2, 3 (3 leaves). m = 2. Edges: 1-2, 3-0 (or 3-1).
    dut._log.info("Test Case 1: Star graph N=4, h=0")
    n = 4
    h = 0
    edges = [(0,1), (0,2), (0,3)]
    
    dut.n_minus_1_edges_count.value = n - 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed edges
    for i, (u, v) in enumerate(edges):
        dut.u.value = u
        dut.v.value = v
        dut.edge_index.value = i
        await RisingEdge(dut.clk)
    
    # Wait for computation (assume 20 cycles max for small N)
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Module did not finish in time")
    
    m = int(dut.m.value)
    dut._log.info(f"Calculated m: {m}")
    # Expected m = 2 for 3 leaves
    if m != 2:
        raise TestFailure(f"Expected m=2, got {m}")
    
    # Check first output edge
    u1, v1 = int(dut.out_u.value), int(dut.out_v.value)
    dut._log.info(f"Output edge 1: {u1} - {v1}")
    # Should be 1-2 (leaves sorted)
    # Note: Implementation might output 1-2, then 3-0 or 3-1
    # We just verify it's a valid connection among leaves or root
    # Valid edges for N=4, h=0: (1,2) and (3,0) or (3,1).
    # Let's just check connectivity properties? Hard in testbench.
    # Let's check if m output matches.
    
    # Read second edge (if module supports sequential output, need to handle that. 
    # Based on spec, module outputs one edge pair at 'out_u', 'out_v'. 
    # We need to read them sequentially or check valid bits. 
    # Assuming module pulses 'done' or has 'valid' for each output. 
    # Let's assume 'done' stays high and we can sample 'out_u', 'out_v'.
    # If the module needs to output multiple edges, it should have a state machine to emit them.
    # Let's read the second edge.
    await RisingEdge(dut.clk)
    u2, v2 = int(dut.out_u.value), int(dut.out_v.value)
    dut._log.info(f"Output edge 2: {u2} - {v2}")
    
    # Test Case 2: Linear chain with 6 nodes (0-1-2-3-4-5)
    # Leaves: 0, 5 (and maybe others if branch). Wait, sample input: 6 0, edges: 0-1, 0-2, 0-3, 1-4, 1-5.
    # This is: 0 connected to 1,2,3. 1 connected to 0,4,5.
    # Leaves: 2, 3, 4, 5. 4 leaves. m = 2. Edges: 2-3, 4-5 (or similar).
    dut._log.info("Test Case 2: Tree N=6, h=0")
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    n = 6
    h = 0
    edges = [(0,1), (0,2), (0,3), (1,4), (1,5)]
    
    dut.n_minus_1_edges_count.value = n - 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i, (u, v) in enumerate(edges):
        dut.u.value = u
        dut.v.value = v
        dut.edge_index.value = i
        await RisingEdge(dut.clk)
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Module did not finish for Test 2")
    
    m = int(dut.m.value)
    if m != 2:
        raise TestFailure(f"Test 2: Expected m=2, got {m}")
    
    dut._log.info(f"Test 2 Passed: m={m}")
