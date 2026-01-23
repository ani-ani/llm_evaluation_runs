import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_network_unused_switches(dut):
    """Test the network unused switches detection module."""
    
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.length_matrix.value = 0
    dut.hop_matrix.value = 0
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 7 nodes, same as sample input 1
    # Graph edges: 
    # 1-2 (2), 1-3 (1), 1-4 (3)
    # 2-6 (1), 2-7 (2)
    # 3-5 (1)
    # 4-7 (2)
    # 5-7 (1)
    # Expected unused: 4, 6
    
    dut.num_nodes.value = 7
    
    # Initialize matrices to 0
    for i in range(9):
        for j in range(9):
            dut.length_matrix[i][j].value = 0
            dut.hop_matrix[i][j].value = 0
    
    # Helper to set edge
    def set_edge(u, v, length):
        dut.length_matrix[u][v].value = length
        dut.length_matrix[v][u].value = length
        dut.hop_matrix[u][v].value = 1
        dut.hop_matrix[v][u].value = 1
    
    set_edge(1, 2, 2)
    set_edge(1, 3, 1)
    set_edge(1, 4, 3)
    set_edge(2, 6, 1)
    set_edge(2, 7, 2)
    set_edge(3, 5, 1)
    set_edge(4, 7, 2)
    set_edge(5, 7, 1)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for computation to finish (max 2000 cycles, but logic should be faster)
    # For simulation, we'll wait a reasonable amount of time based on the state machine logic
    # The logic involves BFS/Dijkstra on 8 nodes, so it should be fast.
    # We will just wait 500 cycles to be safe for the simulation.
    for _ in range(500):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            break
    
    if dut.valid.value != 1:
        raise TestFailure("Module did not assert valid within timeout")
    
    # Check result for Test Case 1
    # Expected: 4 and 6 are unused. Mask should have bits 3 and 5 set (0-indexed)
    # Switch 1 is bit 0, Switch 2 is bit 1, ..., Switch 7 is bit 6
    # Expected unused: 4 (bit 3), 6 (bit 5)
    expected_mask_1 = (1 << 3) | (1 << 5)
    
    if int(dut.unused_mask.value) != expected_mask_1:
        dut._log.info(f"Test Case 1 Failed. Mask: {int(dut.unused_mask.value):08b}, Expected: {expected_mask_1:08b}")
        # Identify which switches failed
        for i in range(1, 8):
            bit = 1 << (i-1)
            is_unused_hw = (int(dut.unused_mask.value) & bit) != 0
            is_unused_exp = (expected_mask_1 & bit) != 0
            if is_unused_hw != is_unused_exp:
                dut._log.info(f"  Switch {i}: HW={'Unused' if is_unused_hw else 'Used'}, Expected={'Unused' if is_unused_exp else 'Used'}")
        raise TestFailure("Test Case 1: Incorrect unused switches detected")
    
    dut._log.info("Test Case 1 Passed: Correct unused switches (4, 6) detected")
    
    # Test Case 2: 5 nodes, sample input 2
    # Expected: 0 unused
    # Reset for next test (simulating a new input frame)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    dut.num_nodes.value = 5
    
    # Clear matrix
    for i in range(9):
        for j in range(9):
            dut.length_matrix[i][j].value = 0
            dut.hop_matrix[i][j].value = 0
    
    set_edge(1, 2, 2)
    set_edge(2, 3, 2)
    set_edge(3, 5, 2)
    set_edge(1, 4, 3)
    set_edge(4, 5, 3)
    set_edge(1, 5, 6)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(500):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            break
            
    if dut.valid.value != 1:
        raise TestFailure("Module did not assert valid for Test Case 2")
        
    if int(dut.unused_mask.value) != 0:
        raise TestFailure(f"Test Case 2 Failed. Mask: {int(dut.unused_mask.value):08b}, Expected: 0")
    
    dut._log.info("Test Case 2 Passed: No switches detected as unused")
    
    # Test Case 3: 5 nodes, sample input 3 (modified)
    # Edges: 1-2(2), 2-3(1), 3-5(2), 1-4(3), 4-5(3), 1-5(6)
    # Path 1->2->3->5: Len 5, Hops 3
    # Path 1->4->5: Len 6, Hops 2
    # Path 1->5: Len 6, Hops 1
    # For c=0, shortest is 1-2-3-5 (Len 5). Node 4 not used.
    # For c=1, costs: Path1=8, Path2=8, Path3=7. Node 4 not used.
    # Wait, let's re-evaluate Path 1-4-5 vs 1-5.
    # P1: L=6, H=1 -> 6/v + c
    # P2: L=6, H=2 -> 6/v + 2c
    # P1 is always better or equal to P2. P1 dominates P2.
    # So P2 is never optimal. Node 4 is not on P1 or P3 (1-2-3-5).
    # Wait, check sample output 3: 1
    # 4
    # So node 4 is unused.
    
    dut.num_nodes.value = 5
    for i in range(9):
        for j in range(9):
            dut.length_matrix[i][j].value = 0
            dut.hop_matrix[i][j].value = 0
            
    set_edge(1, 2, 2)
    set_edge(2, 3, 1) # Changed from 2 to 1
    set_edge(3, 5, 2)
    set_edge(1, 4, 3)
    set_edge(4, 5, 3)
    set_edge(1, 5, 6)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(500):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            break
            
    if dut.valid.value != 1:
        raise TestFailure("Module did not assert valid for Test Case 3")
        
    # Expected unused: 4
    expected_mask_3 = (1 << 3) # Switch 4
    
    if int(dut.unused_mask.value) != expected_mask_3:
        raise TestFailure(f"Test Case 3 Failed. Mask: {int(dut.unused_mask.value):08b}, Expected: {expected_mask_3:08b}")
        
    dut._log.info("Test Case 3 Passed: Switch 4 detected as unused")