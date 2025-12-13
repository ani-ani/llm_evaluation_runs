import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_critical_path(dut):
    # Create 50MHz clock
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())
    
    # Define test cases (scaled from original samples)
    test_cases = [
        (# Case 1: Original Sample 1 scaled
         node_count=4, edge_count=4, edges=[(1,2), (1,3), (3,4), (2,4)],
         expected=2),
        (# Case 2: Original Sample 2 scaled
         node_count=7, edge_count=6, edges=[(1,2), (2,3), (2,5), (6,3), (7,2), (3,4)],
         expected=2),
        (# Case 3: Original Sample 3 scaled
         node_count=7, edge_count=5, edges=[(1,2), (2,3), (3,4), (5,6), (6,7)],
         expected=0),
        (# Case 4: Original Sample 4 scaled
         node_count=6, edge_count=5, edges=[(1,2), (1,4), (2,3), (4,5), (5,6)],
         expected=1)
    ]
    
    # Flatten edge list helper
    def flatten_edges(edges, max_edges=16):
        flattened = 0
        for i, (u, v) in enumerate(edges):
            if i >= max_edges: break
            flattened |= (u & 0x7) << (i*6) | (v & 0x7) << (i*6+3)
        return flattened
    
    passed = 0
    total = len(test_cases)
    
    for case in test_cases:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Apply inputs
        dut.node_count.value = case[0]
        dut.edge_count.value = case[1]
        dut.edge_list.value = flatten_edges(case[2])
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (allow 100 cycles max)
        cycles = 0
        while not dut.done.value and cycles < 100:
            await RisingEdge(dut.clk)
            cycles += 1
        
        # Check result
        if dut.done.value and dut.result.value == case[3]:
            passed += 1
        else:
            dut._log.error(f"Test failed: Nodes {case[0]}, Edges {case[2]}. Got {dut.result.value}, expected {case[3]}")
        
        # Small delay between cases
        await Timer(500, units="ns")
    
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total