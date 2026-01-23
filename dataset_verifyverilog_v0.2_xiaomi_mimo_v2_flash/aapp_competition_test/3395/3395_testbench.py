import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_steel_age_solver(dut):
    """Test Steel Age solver with various graph configurations"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.iron_mask.value = 0
    dut.coal_mask.value = 0
    for i in range(8):
        for j in range(8):
            dut.graph[i][j].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test Case 1: Simple chain 1->2->3, iron at 2, coal at 3
    # Expected: 2 settlers (claim 2 and 3)
    dut._log.info("Test Case 1: Linear chain 1->2->3")
    
    # Clear and setup
    for i in range(8):
        for j in range(8):
            dut.graph[i][j].value = 0
    
    # 1->2, 2->3 (node 0->1, 1->2)
    dut.graph[0][1].value = 1
    dut.graph[1][2].value = 1
    
    # iron at node 2 (cell 2), coal at node 2 (cell 3) = nodes 1,2
    dut.iron_mask.value = 0b00000010  # node 1 (cell 2)
    dut.coal_mask.value  = 0b00000100  # node 2 (cell 3)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 64 cycles)
    for _ in range(70):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Test 1: Did not complete in 70 cycles")
    
    if not dut.possible.value:
        raise TestFailure("Test 1: Should be possible")
    
    if int(dut.min_settlers.value) != 2:
        raise TestFailure(f"Test 1: Expected 2, got {int(dut.min_settlers.value)}")
    
    dut._log.info(f"Test 1: PASSED - min_settlers = {int(dut.min_settlers.value)}")
    
    await Timer(100, units='ns')
    
    # Test Case 2: Same chain but iron at 2 only (no coal reachable)
    # Expected: impossible
    dut._log.info("Test Case 2: Only iron reachable")
    
    for i in range(8):
        for j in range(8):
            dut.graph[i][j].value = 0
    
    dut.graph[0][1].value = 1
    dut.graph[1][2].value = 1
    
    dut.iron_mask.value = 0b00000010  # node 1 (cell 2)
    dut.coal_mask.value = 0b00000000  # no coal
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(70):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Test 2: Did not complete")
    
    if dut.possible.value:
        raise TestFailure("Test 2: Should be impossible")
    
    dut._log.info("Test 2: PASSED - correctly detected impossible")
    
    await Timer(100, units='ns')
    
    # Test Case 3: Diamond graph with shared path
    # 1->2, 1->3, 2->4, 3->4
    # iron at 2, coal at 3
    # Path 1: 1->2 (iron), 1->3 (coal): cost = 2
    # Path 2: 1->2->4, 1->3->4: cost = 2 + 2 = 4 (worse)
    # Expected: 2 (via separate paths from 1)
    dut._log.info("Test Case 3: Diamond graph")
    
    for i in range(8):
        for j in range(8):
            dut.graph[i][j].value = 0
    
    dut.graph[0][1].value = 1  # 1->2
    dut.graph[0][2].value = 1  # 1->3
    dut.graph[1][3].value = 1  # 2->4
    dut.graph[2][3].value = 1  # 3->4
    
    dut.iron_mask.value = 0b00000010  # node 1 (cell 2)
    dut.coal_mask.value  = 0b00000100  # node 2 (cell 3)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(70):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Test 3: Did not complete")
    
    if not dut.possible.value:
        raise TestFailure("Test 3: Should be possible")
    
    if int(dut.min_settlers.value) != 2:
        raise TestFailure(f"Test 3: Expected 2, got {int(dut.min_settlers.value)}")
    
    dut._log.info(f"Test 3: PASSED - min_settlers = {int(dut.min_settlers.value)}")
    
    await Timer(100, units='ns')
    
    # Test Case 4: Single node contains iron, same node has coal (shouldn't happen per spec, but test)
    # 1->2, iron and coal at 2
    # Expected: 1 (claim node 2 once)
    dut._log.info("Test Case 4: Same node has both resources")
    
    for i in range(8):
        for j in range(8):
            dut.graph[i][j].value = 0
    
    dut.graph[0][1].value = 1
    
    dut.iron_mask.value = 0b00000010  # node 1
    dut.coal_mask.value = 0b00000010  # node 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(70):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Test 4: Did not complete")
    
    if not dut.possible.value:
        raise TestFailure("Test 4: Should be possible")
    
    # Should be 1 since one node claims both
    if int(dut.min_settlers.value) != 1:
        raise TestFailure(f"Test 4: Expected 1, got {int(dut.min_settlers.value)}")
    
    dut._log.info(f"Test 4: PASSED - min_settlers = {int(dut.min_settlers.value)}")
    
    await Timer(100, units='ns')
    
    # Test Case 5: Disjoint resources requiring two separate explorations
    # 1->2 (iron), 1->3 (coal)
    # Expected: 2 (one settler to 2, one to 3)
    dut._log.info("Test Case 5: Disjoint paths from start")
    
    for i in range(8):
        for j in range(8):
            dut.graph[i][j].value = 0
    
    dut.graph[0][1].value = 1  # 1->2
    dut.graph[0][2].value = 1  # 1->3
    
    dut.iron_mask.value = 0b00000010  # node 1
    dut.coal_mask.value = 0b00000100  # node 2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(70):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Test 5: Did not complete")
    
    if not dut.possible.value:
        raise TestFailure("Test 5: Should be possible")
    
    if int(dut.min_settlers.value) != 2:
        raise TestFailure(f"Test 5: Expected 2, got {int(dut.min_settlers.value)}")
    
    dut._log.info(f"Test 5: PASSED - min_settlers = {int(dut.min_settlers.value)}")
    
    dut._log.info("
=== All 5 tests passed! ===")
