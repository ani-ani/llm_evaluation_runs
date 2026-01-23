import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_min_co2_match(dut):
    """Test minimum CO2 matching for 8 students"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.p_idx.value = 0
    dut.q_idx.value = 0
    dut.weight.value = 0
    dut.weight_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test Case 1: 4-node graph with perfect matching
    # Graph: 0-1 (375), 2-3 (98)
    # Expected: 375 + 98 = 473 grams
    # Q16.16: 473 * 65536 = 0x001D9000
    
    dut.start.value = 1
    await Timer(20, units='ns')
    dut.start.value = 0
    
    # Load weights
    dut.weight_valid.value = 1
    
    # Edge 0-1: weight 375
    dut.p_idx.value = 0
    dut.q_idx.value = 1
    dut.weight.value = 375 << 16  # Q16.16 format
    await RisingEdge(dut.clk)
    
    # Edge 2-3: weight 98
    dut.p_idx.value = 2
    dut.q_idx.value = 3
    dut.weight.value = 98 << 16
    await RisingEdge(dut.clk)
    
    # Add dummy edges to complete 8-node requirement
    # Add edges 4-5 (0), 6-7 (0) to make perfect matching possible
    dut.p_idx.value = 4
    dut.q_idx.value = 5
    dut.weight.value = 0
    await RisingEdge(dut.clk)
    
    dut.p_idx.value = 6
    dut.q_idx.value = 7
    dut.weight.value = 0
    await RisingEdge(dut.clk)
    
    dut.weight_valid.value = 0
    
    # Wait for computation
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Check results
    if dut.done.value != 1:
        raise TestFailure("Test 1: Done not asserted within 25 cycles")
    
    expected = 473 << 16  # Q16.16 format
    if dut.impossible.value == 1:
        raise TestFailure("Test 1: Incorrectly reported impossible")
    if int(dut.result.value) != expected:
        raise TestFailure(f"Test 1: Expected {expected} (0x{expected:08X}), got {int(dut.result.value)} (0x{int(dut.result.value):08X})")
    
    print(f"Test 1 passed: Total cost = {int(dut.result.value) >> 16} grams")
    
    # Test Case 2: 4-node graph with NO perfect matching (isolated vertex)
    # Reset and test again
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    dut.start.value = 1
    await Timer(20, units='ns')
    dut.start.value = 0
    
    dut.weight_valid.value = 1
    
    # Edge 0-1: 375
    dut.p_idx.value = 0
    dut.q_idx.value = 1
    dut.weight.value = 375 << 16
    await RisingEdge(dut.clk)
    
    # Edge 1-2: 200 (creates triangle, node 3 isolated)
    dut.p_idx.value = 1
    dut.q_idx.value = 2
    dut.weight.value = 200 << 16
    await RisingEdge(dut.clk)
    
    # No edge involving node 3 (isolated)
    # Add dummy edges for 4-7 but not covering node 3
    dut.p_idx.value = 4
    dut.q_idx.value = 5
    dut.weight.value = 0
    await RisingEdge(dut.clk)
    
    dut.p_idx.value = 6
    dut.q_idx.value = 7
    dut.weight.value = 0
    await RisingEdge(dut.clk)
    
    dut.weight_valid.value = 0
    
    # Wait for computation
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 2: Done not asserted within 25 cycles")
    
    if dut.impossible.value != 1:
        raise TestFailure("Test 2: Should report impossible for isolated node")
    
    print("Test 2 passed: Correctly reported impossible")
    
    # Test Case 3: Complete matching with higher costs
    # 4 nodes: 0-1 (500), 2-3 (400) -> total 900
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    dut.start.value = 1
    await Timer(20, units='ns')
    dut.start.value = 0
    
    dut.weight_valid.value = 1
    
    dut.p_idx.value = 0
    dut.q_idx.value = 1
    dut.weight.value = 500 << 16
    await RisingEdge(dut.clk)
    
    dut.p_idx.value = 2
    dut.q_idx.value = 3
    dut.weight.value = 400 << 16
    await RisingEdge(dut.clk)
    
    dut.p_idx.value = 4
    dut.q_idx.value = 5
    dut.weight.value = 0
    await RisingEdge(dut.clk)
    
    dut.p_idx.value = 6
    dut.q_idx.value = 7
    dut.weight.value = 0
    await RisingEdge(dut.clk)
    
    dut.weight_valid.value = 0
    
    # Wait for computation
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 3: Done not asserted within 25 cycles")
    
    expected = 900 << 16
    if dut.impossible.value == 1:
        raise TestFailure("Test 3: Incorrectly reported impossible")
    if int(dut.result.value) != expected:
        raise TestFailure(f"Test 3: Expected {expected} (0x{expected:08X}), got {int(dut.result.value)} (0x{int(dut.result.value):08X})")
    
    print(f"Test 3 passed: Total cost = {int(dut.result.value) >> 16} grams")
    print("
All 3/3 tests passed!")
