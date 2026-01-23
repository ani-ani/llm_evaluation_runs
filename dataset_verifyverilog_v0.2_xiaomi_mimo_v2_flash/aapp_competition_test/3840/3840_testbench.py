import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_pirate_chest_solver(dut):
    """Test the pirate chest solver with various test cases"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(15):
        dut.coins[i].value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=1 (should return -1)
    dut._log.info("Test 1: n=1 (invalid)")
    dut.n.value = 1
    dut.coins[0].value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 1 Result: {result}")
    assert result == 65535 or result == -1, f"Test 1 failed: expected -1 or 65535, got {result}"
    
    await Timer(100, units='ns')
    
    # Test case 2: n=3, coins=[1,2,3] (should return 3)
    dut._log.info("Test 2: n=3, coins=[1,2,3]")
    dut.n.value = 3
    dut.coins[0].value = 1
    dut.coins[1].value = 2
    dut.coins[2].value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 2 Result: {result}")
    assert result == 3, f"Test 2 failed: expected 3, got {result}"
    
    await Timer(100, units='ns')
    
    # Test case 3: n=5, coins=[2,2,2,2,2]
    dut._log.info("Test 3: n=5, coins=[2,2,2,2,2]")
    dut.n.value = 5
    dut.coins[0].value = 2
    dut.coins[1].value = 2
    dut.coins[2].value = 2
    dut.coins[3].value = 2
    dut.coins[4].value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 3: Timeout waiting for done")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 3 Result: {result}")
    # Expected: Chest5(2) -> Chest2(2-2=0), count=2; Chest4(2) -> Chest2(0-2 clamped to 0), count=2; Chest3(2) -> Chest1(2-2=0), count=2; Chest2(0), Chest1(0) -> total 6
    assert result == 6, f"Test 3 failed: expected 6, got {result}"
    
    await Timer(100, units='ns')
    
    # Test case 4: n=5, coins=[1,1,2,4,4] (should return 4)
    dut._log.info("Test 4: n=5, coins=[1,1,2,4,4]")
    dut.n.value = 5
    dut.coins[0].value = 1
    dut.coins[1].value = 1
    dut.coins[2].value = 2
    dut.coins[3].value = 4
    dut.coins[4].value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 4: Timeout waiting for done")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 4 Result: {result}")
    assert result == 4, f"Test 4 failed: expected 4, got {result}"
    
    await Timer(100, units='ns')
    
    # Test case 5: n=4 (even, should return -1)
    dut._log.info("Test 5: n=4 (even, invalid)")
    dut.n.value = 4
    dut.coins[0].value = 1
    dut.coins[1].value = 2
    dut.coins[2].value = 3
    dut.coins[3].value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 5: Timeout waiting for done")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 5 Result: {result}")
    assert result == 65535 or result == -1, f"Test 5 failed: expected -1 or 65535, got {result}"
    
    await Timer(100, units='ns')
    
    # Test case 6: n=9, coins=[1,1,1,1,1,1,1,1,1]
    dut._log.info("Test 6: n=9, all coins=1")
    dut.n.value = 9
    for i in range(9):
        dut.coins[i].value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 6: Timeout waiting for done")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 6 Result: {result}")
    assert result == 5, f"Test 6 failed: expected 5, got {result}"
    
    await Timer(100, units='ns')
    
    dut._log.info("All tests passed!")
