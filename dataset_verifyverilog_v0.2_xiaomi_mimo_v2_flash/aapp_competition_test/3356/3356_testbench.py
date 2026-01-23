import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

@cocotb.test()
async def test_mole_residence(dut):
    """Test the mole residence reconstruction logic"""
    
    # Initialize signals
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.input_valid.value = 0
    dut.input_done.value = 0
    dut.node_a_i.value = 0
    dut.node_b_i.value = 0
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper to send edge
    async def send_edge(a, b):
        dut.node_a_i.value = a
        dut.node_b_i.value = b
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
        dut.input_valid.value = 0
        await RisingEdge(dut.clk)
    
    async def run_test(edges, expected_diameter, expected_close, expected_open):
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for INPUT_EDGES state (implied by start)
        # Send edges
        for (u, v) in edges:
            await send_edge(u, v)
            
        # Signal done
        dut.input_done.value = 1
        await RisingEdge(dut.clk)
        dut.input_done.value = 0
        
        # Wait for computation to finish
        # The module needs a few cycles to process
        # We wait until computation_done is high
        max_cycles = 50
        for _ in range(max_cycles):
            if dut.computation_done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check results
        diameter = int(dut.diameter_result.value)
        close_a = int(dut.close_node_a.value)
        close_b = int(dut.close_node_b.value)
        open_a = int(dut.open_node_a.value)
        open_b = int(dut.open_node_b.value)
        
        print(f"Computed Diameter: {diameter}, Expected: {expected_diameter}")
        print(f"Close: {close_a}-{close_b}, Expected: {expected_close}")
        print(f"Open: {open_a}-{open_b}, Expected: {expected_open}")
        
        assert diameter == expected_diameter, f"Diameter mismatch: {diameter} vs {expected_diameter}"
        
        # Check close pair (order insensitive)
        close_match = (close_a == expected_close[0] and close_b == expected_close[1]) or \
                      (close_a == expected_close[1] and close_b == expected_close[0])
        assert close_match, f"Close mismatch: ({close_a},{close_b}) vs {expected_close}"
        
        # Check open pair (order insensitive)
        open_match = (open_a == expected_open[0] and open_b == expected_open[1]) or \
                     (open_a == expected_open[1] and open_b == expected_open[0])
        assert open_match, f"Open mismatch: ({open_a},{open_b}) vs {expected_open}"

    # Test Case 1: Line 1-2-3-4
    # Diameter 3. Path [1,2,3,4]. Center 2 (index 1).
    # Strategy: Cut (3,4), Open (4,2).
    await run_test([(1,2), (2,3), (3,4)], 2, (3,4), (4,2))
    
    # Test Case 2: 7 nodes
    # Edges: 1-3, 2-3, 2-7, 4-3, 7-5, 3-6
    # Graph structure: 3 is central. 1,4,6 are leaves. 2 connects to 7. 7 connects to 5.
    # Longest path: 1-3-2-7-5 (length 4) or 6-3-2-7-5 (length 4).
    # Diameter = 4.
    # Path: [6, 3, 2, 7, 5]. Length 4. Nodes 5.
    # Center index 2 (value 2).
    # Leaf is 5. Parent is 7.
    # Cut (7, 5). Open (5, 2).
    # New diameter? Path 6-3-2-5 -> length 3. Or 1-3-2-5 -> length 3.
    # So diameter becomes 3.
    # Expected output: 3, close (7,5), open (5,2).
    await run_test([(1,3), (2,3), (2,7), (4,3), (7,5), (3,6)], 3, (7,5), (5,2))

    print("All tests passed!")
