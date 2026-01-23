import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_executive_reward(dut):
    """Test the executive_reward module with various test cases"""
    
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_briefcases.value = 0
    for i in range(8):
        dut.bananas[i].value = 0
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 4 briefcases with [1, 2, 1, 2]
    # Original: 3 executives expected
    # Scale: Banana values in Q16.8 (multiply by 256)
    dut.num_briefcases.value = 4
    dut.bananas[0].value = 1 * 256    # 1
    dut.bananas[1].value = 2 * 256    # 2
    dut.bananas[2].value = 1 * 256    # 1
    dut.bananas[3].value = 2 * 256    # 2
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 64 cycles)
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test Case 1: Done signal not asserted within 100 cycles")
    
    if dut.max_executives.value != 3:
        raise TestFailure(f"Test Case 1: Expected 3 executives, got {int(dut.max_executives.value)}")
    
    print(f"Test Case 1 PASSED: 4 briefcases [1,2,1,2] -> {int(dut.max_executives.value)} executives")
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    
    # Test Case 2: 6 briefcases with [6, 4, 2, 2, 2, 2]
    # Original: 3 executives expected
    # Strategy: [6] = 6, [4,2] = 6, [2,2,2] = 6
    dut.num_briefcases.value = 6
    dut.bananas[0].value = 6 * 256
    dut.bananas[1].value = 4 * 256
    dut.bananas[2].value = 2 * 256
    dut.bananas[3].value = 2 * 256
    dut.bananas[4].value = 2 * 256
    dut.bananas[5].value = 2 * 256
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test Case 2: Done signal not asserted within 100 cycles")
    
    if dut.max_executives.value != 3:
        raise TestFailure(f"Test Case 2: Expected 3 executives, got {int(dut.max_executives.value)}")
    
    print(f"Test Case 2 PASSED: 6 briefcases [6,4,2,2,2,2] -> {int(dut.max_executives.value)} executives")
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    
    # Test Case 3: Simple case with 2 briefcases [1, 1]
    # Expected: 2 executives (each gets 1)
    dut.num_briefcases.value = 2
    dut.bananas[0].value = 1 * 256
    dut.bananas[1].value = 1 * 256
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test Case 3: Done signal not asserted within 100 cycles")
    
    if dut.max_executives.value != 2:
        raise TestFailure(f"Test Case 3: Expected 2 executives, got {int(dut.max_executives.value)}")
    
    print(f"Test Case 3 PASSED: 2 briefcases [1,1] -> {int(dut.max_executives.value)} executives")
    
    # Summary
    print("
All 3/3 tests passed!")
