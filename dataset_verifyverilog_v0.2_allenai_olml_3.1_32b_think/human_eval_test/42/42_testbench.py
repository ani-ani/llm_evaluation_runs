import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_incr_list(dut):
    """Test incr_list module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.data_in_valid.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Empty list (length=0)
    dut._log.info("Test 1: Empty list")
    dut.start.value = 1
    dut.length.value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 10
    for i in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for done (test 1)")
    
    await RisingEdge(dut.clk)
    
    # Test case 2: [3, 2, 1] -> [4, 3, 2]
    dut._log.info("Test 2: [3, 2, 1] -> [4, 3, 2]")
    input_data = [3, 2, 1]
    expected = [4, 3, 2]
    dut.start.value = 1
    dut.length.value = len(input_data)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed inputs
    for val in input_data:
        dut.data_in.value = val
        dut.data_in_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_in_valid.value = 0
    
    # Collect outputs
    outputs = []
    timeout = 20
    for i in range(timeout):
        if dut.data_out_valid.value == 1:
            outputs.append(int(dut.data_out.value))
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for done (test 2)")
    
    if outputs != expected:
        raise TestFailure(f"Test 2 failed: got {outputs}, expected {expected}")
    
    await RisingEdge(dut.clk)
    
    # Test case 3: [5, 2, 5, 2, 3, 3, 9, 0] -> [6, 3, 6, 3, 4, 4, 10, 1]
    dut._log.info("Test 3: [5, 2, 5, 2, 3, 3, 9, 0] -> [6, 3, 6, 3, 4, 4, 10, 1]")
    input_data = [5, 2, 5, 2, 3, 3, 9, 0]
    expected = [6, 3, 6, 3, 4, 4, 10, 1]
    dut.start.value = 1
    dut.length.value = len(input_data)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed inputs
    for val in input_data:
        dut.data_in.value = val
        dut.data_in_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_in_valid.value = 0
    
    # Collect outputs
    outputs = []
    timeout = 25
    for i in range(timeout):
        if dut.data_out_valid.value == 1:
            outputs.append(int(dut.data_out.value))
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for done (test 3)")
    
    if outputs != expected:
        raise TestFailure(f"Test 3 failed: got {outputs}, expected {expected}")
    
    # Test case 4: Random test with 5 elements
    dut._log.info("Test 4: Random 5 elements")
    input_data = [random.randint(0, 250) for _ in range(5)]
    expected = [x + 1 for x in input_data]
    dut.start.value = 1
    dut.length.value = len(input_data)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed inputs
    for val in input_data:
        dut.data_in.value = val
        dut.data_in_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_in_valid.value = 0
    
    # Collect outputs
    outputs = []
    timeout = 20
    for i in range(timeout):
        if dut.data_out_valid.value == 1:
            outputs.append(int(dut.data_out.value))
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for done (test 4)")
    
    if outputs != expected:
        raise TestFailure(f"Test 4 failed: got {outputs}, expected {expected}")
    
    # Test case 5: Single element
    dut._log.info("Test 5: Single element [123] -> [124]")
    input_data = [123]
    expected = [124]
    dut.start.value = 1
    dut.length.value = len(input_data)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed inputs
    for val in input_data:
        dut.data_in.value = val
        dut.data_in_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_in_valid.value = 0
    
    # Collect outputs
    outputs = []
    timeout = 15
    for i in range(timeout):
        if dut.data_out_valid.value == 1:
            outputs.append(int(dut.data_out.value))
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for done (test 5)")
    
    if outputs != expected:
        raise TestFailure(f"Test 5 failed: got {outputs}, expected {expected}")
    
    dut._log.info("All 5/5 tests passed!")
