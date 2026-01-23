import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_good_sequence_solver(dut):
    """Test the good sequence solver module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(16):
        dut.a[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: [2, 3, 4, 6, 9] -> Expected: 4 (sequence [2, 4, 6, 9])
    dut.n.value = 5
    dut.a[0].value = 2
    dut.a[1].value = 3
    dut.a[2].value = 4
    dut.a[3].value = 6
    dut.a[4].value = 9
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.result.value != 4:
        raise TestFailure(f"Test 1 Failed: Expected 4, got {int(dut.result.value)}")
    dut._log.info("Test 1 passed: [2,3,4,6,9] -> 4")
    
    await RisingEdge(dut.clk)
    await Timer(20, units='ns')
    
    # Test Case 2: [1, 2, 3, 5, 6, 7, 8, 9, 10] -> Expected: 4
    dut.n.value = 9
    dut.a[0].value = 1
    dut.a[1].value = 2
    dut.a[2].value = 3
    dut.a[3].value = 5
    dut.a[4].value = 6
    dut.a[5].value = 7
    dut.a[6].value = 8
    dut.a[7].value = 9
    dut.a[8].value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.result.value != 4:
        raise TestFailure(f"Test 2 Failed: Expected 4, got {int(dut.result.value)}")
    dut._log.info("Test 2 passed: [1,2,3,5,6,7,8,9,10] -> 4")
    
    await RisingEdge(dut.clk)
    await Timer(20, units='ns')
    
    # Test Case 3: [1, 2, 4, 6] -> Expected: 3
    dut.n.value = 4
    dut.a[0].value = 1
    dut.a[1].value = 2
    dut.a[2].value = 4
    dut.a[3].value = 6
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.result.value != 3:
        raise TestFailure(f"Test 3 Failed: Expected 3, got {int(dut.result.value)}")
    dut._log.info("Test 3 passed: [1,2,4,6] -> 3")
    
    await RisingEdge(dut.clk)
    await Timer(20, units='ns')
    
    # Test Case 4: [1] -> Expected: 1
    dut.n.value = 1
    dut.a[0].value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 4 Failed: Expected 1, got {int(dut.result.value)}")
    dut._log.info("Test 4 passed: [1] -> 1")
    
    await RisingEdge(dut.clk)
    await Timer(20, units='ns')
    
    # Test Case 5: [2, 3, 7, 9, 10] -> Expected: 2
    dut.n.value = 5
    dut.a[0].value = 2
    dut.a[1].value = 3
    dut.a[2].value = 7
    dut.a[3].value = 9
    dut.a[4].value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.result.value != 2:
        raise TestFailure(f"Test 5 Failed: Expected 2, got {int(dut.result.value)}")
    dut._log.info("Test 5 passed: [2,3,7,9,10] -> 2")
    
    dut._log.info("All tests passed!")
