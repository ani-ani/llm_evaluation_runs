import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_unique(dut):
    """Test unique function with various test cases"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = [0] * 8
    dut.valid_count.value = 0
    await Timer(25, units='ns')
    
    # Release reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Original example
    dut._log.info("Test 1: Original example [5,3,5,2,3,3,9,0,123]")
    # Use 8 elements (truncate 123 to fit)
    data = [5, 3, 5, 2, 3, 3, 9, 0]
    expected = [0, 2, 3, 5, 9]
    
    # Load data
    for i in range(8):
        dut.data_in[i].value = data[i]
    dut.valid_count.value = 8
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 60 cycles for safety)
    cycles = 0
    while not dut.done.value and cycles < 60:
        await RisingEdge(dut.clk)
        cycles += 1
    
    # Check results
    assert dut.done.value == 1, f"Done not set after {cycles} cycles"
    unique_count = int(dut.unique_count.value)
    
    dut._log.info(f"  Unique count: {unique_count}")
    
    actual = []
    for i in range(unique_count):
        val = int(dut.result[i].value)
        actual.append(val)
        dut._log.info(f"  result[{i}] = {val}")
    
    assert actual == expected, f"Expected {expected}, got {actual}"
    
    await RisingEdge(dut.clk)
    
    # Test case 2: All duplicates
    dut._log.info("Test 2: All duplicates [7,7,7,7,7,7,7,7]")
    data = [7, 7, 7, 7, 7, 7, 7, 7]
    expected = [7]
    
    for i in range(8):
        dut.data_in[i].value = data[i]
    dut.valid_count.value = 8
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 60:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert dut.done.value == 1
    unique_count = int(dut.unique_count.value)
    actual = [int(dut.result[i].value) for i in range(unique_count)]
    
    dut._log.info(f"  Unique count: {unique_count}")
    assert actual == expected, f"Expected {expected}, got {actual}"
    
    await RisingEdge(dut.clk)
    
    # Test case 3: Already sorted unique
    dut._log.info("Test 3: Already sorted [1,2,3,4,5,6,7,8]")
    data = [1, 2, 3, 4, 5, 6, 7, 8]
    expected = [1, 2, 3, 4, 5, 6, 7, 8]
    
    for i in range(8):
        dut.data_in[i].value = data[i]
    dut.valid_count.value = 8
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 60:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert dut.done.value == 1
    unique_count = int(dut.unique_count.value)
    actual = [int(dut.result[i].value) for i in range(unique_count)]
    
    dut._log.info(f"  Unique count: {unique_count}")
    assert actual == expected, f"Expected {expected}, got {actual}"
    
    await RisingEdge(dut.clk)
    
    # Test case 4: Reverse sorted
    dut._log.info("Test 4: Reverse sorted [8,7,6,5,4,3,2,1]")
    data = [8, 7, 6, 5, 4, 3, 2, 1]
    expected = [1, 2, 3, 4, 5, 6, 7, 8]
    
    for i in range(8):
        dut.data_in[i].value = data[i]
    dut.valid_count.value = 8
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 60:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert dut.done.value == 1
    unique_count = int(dut.unique_count.value)
    actual = [int(dut.result[i].value) for i in range(unique_count)]
    
    dut._log.info(f"  Unique count: {unique_count}")
    assert actual == expected, f"Expected {expected}, got {actual}"
    
    await RisingEdge(dut.clk)
    
    # Test case 5: Partial array with duplicates
    dut._log.info("Test 5: Partial array [10,20,10,20,0,0,0,0] (valid_count=4)")
    data = [10, 20, 10, 20, 0, 0, 0, 0]
    expected = [10, 20]
    
    for i in range(8):
        dut.data_in[i].value = data[i]
    dut.valid_count.value = 4
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 60:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert dut.done.value == 1
    unique_count = int(dut.unique_count.value)
    actual = [int(dut.result[i].value) for i in range(unique_count)]
    
    dut._log.info(f"  Unique count: {unique_count}")
    assert actual == expected, f"Expected {expected}, got {actual}"
    
    dut._log.info("All tests passed!")
