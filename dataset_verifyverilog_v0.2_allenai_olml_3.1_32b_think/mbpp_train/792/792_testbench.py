import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_count_list(dut):
    """Test counting lists in a 2D array"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.done_in.value = 0
    dut.data_in.value = 0
    await Timer(30, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: 4 sub-arrays
    dut._log.info("Test 1: 4 sub-arrays")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Simulate 4 sub-arrays with 2 elements each
    for subarray in range(4):
        for elem in range(2):
            dut.valid_in.value = 1
            dut.data_in.value = subarray * 10 + elem
            await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        dut.done_in.value = 1
        await RisingEdge(dut.clk)
        dut.done_in.value = 0
        await RisingEdge(dut.clk)
    
    # Check result
    await Timer(1, units='ns')
    if int(dut.result.value) != 4:
        raise TestFailure(f"Expected 4, got {int(dut.result.value)}")
    if int(dut.done.value) != 1:
        raise TestFailure(f"Expected done=1, got {int(dut.done.value)}")
    
    # Wait for DONE_STATE
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2: 3 sub-arrays
    dut._log.info("Test 2: 3 sub-arrays")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for subarray in range(3):
        for elem in range(2):
            dut.valid_in.value = 1
            dut.data_in.value = subarray * 10 + elem
            await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        dut.done_in.value = 1
        await RisingEdge(dut.clk)
        dut.done_in.value = 0
        await RisingEdge(dut.clk)
    
    await Timer(1, units='ns')
    if int(dut.result.value) != 3:
        raise TestFailure(f"Expected 3, got {int(dut.result.value)}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Reset for test 3
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 3: 2 sub-arrays
    dut._log.info("Test 3: 2 sub-arrays")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for subarray in range(2):
        for elem in range(2):
            dut.valid_in.value = 1
            dut.data_in.value = subarray * 10 + elem
            await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        dut.done_in.value = 1
        await RisingEdge(dut.clk)
        dut.done_in.value = 0
        await RisingEdge(dut.clk)
    
    await Timer(1, units='ns')
    if int(dut.result.value) != 2:
        raise TestFailure(f"Expected 2, got {int(dut.result.value)}")
    
    # Edge case: 8 sub-arrays (maximum)
    dut._log.info("Edge case: 8 sub-arrays")
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for subarray in range(8):
        dut.valid_in.value = 1
        dut.done_in.value = 1
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        dut.done_in.value = 0
        await RisingEdge(dut.clk)
    
    await Timer(1, units='ns')
    if int(dut.result.value) != 8:
        raise TestFailure(f"Expected 8, got {int(dut.result.value)}")
    
    dut._log.info(f"All tests passed! Result final: {int(dut.result.value)}")