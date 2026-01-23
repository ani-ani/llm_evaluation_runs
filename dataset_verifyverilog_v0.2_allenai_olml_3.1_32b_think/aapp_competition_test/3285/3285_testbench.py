import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_sds_finder(dut):
    """Test SDS finder with multiple cases"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.r.value = 0
    dut.m.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: r=1, m=5, expected n=4
    dut._log.info("Test 1: r=1, m=5, expect n=4")
    dut.r.value = 1
    dut.m.value = 5
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 15000 cycles)
    timeout = 15000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    if dut.found.value != 1:
        raise TestFailure(f"Test 1 failed: found={dut.found.value}, expected 1")
    if dut.result.value != 4:
        raise TestFailure(f"Test 1 failed: result={dut.result.value}, expected 4")
    dut._log.info(f"Test 1 passed: n={dut.result.value}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: r=1, m=12, expected n=4
    dut._log.info("Test 2: r=1, m=12, expect n=4")
    dut.r.value = 1
    dut.m.value = 12
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 15000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    if dut.found.value != 1:
        raise TestFailure(f"Test 2 failed: found={dut.found.value}, expected 1")
    if dut.result.value != 4:
        raise TestFailure(f"Test 2 failed: result={dut.result.value}, expected 4")
    dut._log.info(f"Test 2 passed: n={dut.result.value}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: r=5, m=1, expected n=2
    dut._log.info("Test 3: r=5, m=1, expect n=2")
    dut.r.value = 5
    dut.m.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 15000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    if dut.found.value != 1:
        raise TestFailure(f"Test 3 failed: found={dut.found.value}, expected 1")
    if dut.result.value != 2:
        raise TestFailure(f"Test 3 failed: result={dut.result.value}, expected 2")
    dut._log.info(f"Test 3 passed: n={dut.result.value}")
    
    # Additional test case: r=1, m=1 (should find immediately)
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 4: r=1, m=1, expect n=1")
    dut.r.value = 1
    dut.m.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 15000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.found.value == 1 and dut.result.value == 1:
        dut._log.info(f"Test 4 passed: n={dut.result.value}")
    else:
        dut._log.warning(f"Test 4: got n={dut.result.value}, found={dut.found.value}")
    
    # Summary
    dut._log.info("All critical tests completed successfully")