import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_min_diff(dut):
    """Test minimum difference calculator"""
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    dut.data_in.value = 0
    dut.index.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: [1,5,3,19,18,25] -> sorted: [1,3,5,18,19,25] -> min diff = 1 (18-19)
    # We need 8 elements, so pad with [0, 0] -> sorted: [0,0,1,3,5,18,19,25] -> min diff = 0
    # Better: [1,5,3,19,18,25,100,101] -> min diff = 1 (18-19 or 100-101)
    dut._log.info("Test 1: Array [1,5,3,19,18,25,100,101]")
    test_array = [1,5,3,19,18,25,100,101]
    for i, val in enumerate(test_array):
        dut.data_in.value = val
        dut.index.value = i
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    # Expected: 1 (from 100-101 or 18-19)
    expected = 1
    if dut.min_diff.value != expected:
        raise TestFailure(f"Test 1: Expected {expected}, got {int(dut.min_diff.value)}")
    dut._log.info(f"Test 1: PASS - Result {int(dut.min_diff.value)}")
    await RisingEdge(dut.clk)
    
    # Test 2: [4,3,2,6] -> sorted: [2,3,4,6] -> min diff = 1
    # Pad: [4,3,2,6,10,11,12,13] -> sorted: [2,3,4,6,10,11,12,13] -> min diff = 1
    dut._log.info("Test 2: Array [4,3,2,6,10,11,12,13]")
    test_array = [4,3,2,6,10,11,12,13]
    for i, val in enumerate(test_array):
        dut.data_in.value = val
        dut.index.value = i
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    expected = 1
    if dut.min_diff.value != expected:
        raise TestFailure(f"Test 2: Expected {expected}, got {int(dut.min_diff.value)}")
    dut._log.info(f"Test 2: PASS - Result {int(dut.min_diff.value)}")
    await RisingEdge(dut.clk)
    
    # Test 3: [30,5,20,9] -> sorted: [5,9,20,30] -> min diff = 4
    # Pad: [30,5,20,9,50,60,70,80] -> sorted: [5,9,20,30,50,60,70,80] -> min diff = 4
    dut._log.info("Test 3: Array [30,5,20,9,50,60,70,80]")
    test_array = [30,5,20,9,50,60,70,80]
    for i, val in enumerate(test_array):
        dut.data_in.value = val
        dut.index.value = i
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 3: Timeout waiting for done")
    
    expected = 4
    if dut.min_diff.value != expected:
        raise TestFailure(f"Test 3: Expected {expected}, got {int(dut.min_diff.value)}")
    dut._log.info(f"Test 3: PASS - Result {int(dut.min_diff.value)}")
    await RisingEdge(dut.clk)
    
    # Edge case test: All same elements [5,5,5,5,5,5,5,5] -> min diff = 0
    dut._log.info("Test 4: Array [5,5,5,5,5,5,5,5]")
    test_array = [5,5,5,5,5,5,5,5]
    for i, val in enumerate(test_array):
        dut.data_in.value = val
        dut.index.value = i
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 4: Timeout waiting for done")
    
    expected = 0
    if dut.min_diff.value != expected:
        raise TestFailure(f"Test 4: Expected {expected}, got {int(dut.min_diff.value)}")
    dut._log.info(f"Test 4: PASS - Result {int(dut.min_diff.value)}")
    
    dut._log.info("All tests passed!")