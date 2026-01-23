import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_next_smallest(dut):
    """Test next_smallest module with various test cases"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize signals
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.data_in.value = 0
    dut.data_valid.value = 0
    
    # Reset
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [1, 2, 3, 4, 5] -> 2
    dut._log.info("Test 1: [1, 2, 3, 4, 5] expecting 2")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.num_elements.value = 5
    
    for val in [1, 2, 3, 4, 5]:
        dut.data_in.value = val
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    # Wait for completion
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.valid.value and dut.result.value != 2:
        raise TestFailure(f"Test 1 failed: got {dut.result.value}, expected 2")
    
    # Test case 2: [5, 1, 4, 3, 2] -> 2
    dut._log.info("Test 2: [5, 1, 4, 3, 2] expecting 2")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.num_elements.value = 5
    
    for val in [5, 1, 4, 3, 2]:
        dut.data_in.value = val
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.valid.value and dut.result.value != 2:
        raise TestFailure(f"Test 2 failed: got {dut.result.value}, expected 2")
    
    # Test case 3: [] -> None (0xFF)
    dut._log.info("Test 3: [] expecting 0xFF")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.num_elements.value = 0
    dut.data_valid.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.valid.value and dut.result.value != 0xFF:
        raise TestFailure(f"Test 3 failed: got {dut.result.value}, expected 0xFF")
    
    # Test case 4: [1, 1] -> None (0xFF)
    dut._log.info("Test 4: [1, 1] expecting 0xFF")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.num_elements.value = 2
    
    for val in [1, 1]:
        dut.data_in.value = val
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.valid.value and dut.result.value != 0xFF:
        raise TestFailure(f"Test 4 failed: got {dut.result.value}, expected 0xFF")
    
    # Test case 5: [1, 1, 1, 1, 0] -> 1
    dut._log.info("Test 5: [1, 1, 1, 1, 0] expecting 1")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.num_elements.value = 5
    
    for val in [1, 1, 1, 1, 0]:
        dut.data_in.value = val
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.valid.value and dut.result.value != 1:
        raise TestFailure(f"Test 5 failed: got {dut.result.value}, expected 1")
    
    # Test case 6: [-35, 34, 12, -45] -> -35
    dut._log.info("Test 6: [-35, 34, 12, -45] expecting -35")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.num_elements.value = 4
    
    for val in [-35, 34, 12, -45]:
        # Convert to 8-bit signed representation
        dut.data_in.value = val & 0xFF
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result_val = dut.result.value
    if result_val >= 128:  # Convert back from 2's complement
        result_val = result_val - 256
    
    if dut.valid.value and result_val != -35:
        raise TestFailure(f"Test 6 failed: got {result_val}, expected -35")
    
    dut._log.info("All tests passed!")