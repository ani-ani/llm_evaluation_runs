import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_is_undulating(dut):
    """Test is_undulating module with various test cases"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.number.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 1212121 (undulating, 7 digits)
    dut.number.value = 1212121
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 50:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    if not dut.result.value:
        raise TestFailure(f"Test 1: Expected 1212121 to be undulating (True), got {dut.result.value}")
    print("Test 1 passed: 1212121 is undulating")
    
    await RisingEdge(dut.clk)
    await Timer(10, units='ns')
    
    # Test case 2: 1991 (not undulating, 4 digits: 1,9,9,1)
    dut.number.value = 1991
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 50:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    if dut.result.value:
        raise TestFailure(f"Test 2: Expected 1991 to be not undulating (False), got {dut.result.value}")
    print("Test 2 passed: 1991 is not undulating")
    
    await RisingEdge(dut.clk)
 await Timer(10, units='ns')
    
    # Test case 3: 121 (undulating, 3 digits)
    dut.number.value = 121
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 50:
        raise TestFailure("Test 3: Timeout waiting for done")
    
    if not dut.result.value:
        raise TestFailure(f"Test 3: Expected 121 to be undulating (True), got {dut.result.value}")
    print("Test 3 passed: 121 is undulating")
    
    await RisingEdge(dut.clk)
    await Timer(10, units='ns')
    
    # Test case 4: 55 (not undulating, only 2 digits, should return False)
    dut.number.value = 55
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 50:
        raise TestFailure("Test 4: Timeout waiting for done")
    
    if dut.result.value:
        raise TestFailure(f"Test 4: Expected 55 to be not undulating (False), got {dut.result.value}")
    print("Test 4 passed: 55 is not undulating (2 digits)")
    
    await RisingEdge(dut.clk)
    await Timer(10, units='ns')
    
    # Test case 5: 343434 (undulating, 6 digits)
    dut.number.value = 343434
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 50:
        raise TestFailure("Test 5: Timeout waiting for done")
    
    if not dut.result.value:
        raise TestFailure(f"Test 5: Expected 343434 to be undulating (True), got {dut.result.value}")
    print("Test 5 passed: 343434 is undulating")
    
    print("
All tests completed successfully!")