import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_factorial_path_optimizer(dut):
    """Test factorial path optimizer with multiple test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k_value.value = 0
    dut.fragment_count.value = 0
    dut.input_done.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case 1: 3 fragments at k=2,1,4
    dut._log.info("Test Case 1: [2, 1, 4] -> Expected: 5")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    
    # Input fragments
    dut.k_value.value = 2
    dut.fragment_count.value = 1
    dut.input_done.value = 0
    await RisingEdge(dut.clk)
    
    dut.k_value.value = 1
    dut.fragment_count.value = 1
    await RisingEdge(dut.clk)
    
    dut.k_value.value = 4
    dut.fragment_count.value = 1
    await RisingEdge(dut.clk)
    
    dut.input_done.value = 1
    await RisingEdge(dut.clk)
    
    # Wait for computation
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    result = int(dut.total_distance.value)
    dut._log.info(f"Result: {result}")
    assert result == 5 or result == 5, f"Expected 5, got {result}"
    
    # Reset for next test
    dut.start.value = 0
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case 2: [3, 1, 4, 4]
    dut._log.info("Test Case 2: [3, 1, 4, 4] -> Expected: 6")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    
    dut.k_value.value = 3
    dut.fragment_count.value = 1
    dut.input_done.value = 0
    await RisingEdge(dut.clk)
    
    dut.k_value.value = 1
    dut.fragment_count.value = 1
    await RisingEdge(dut.clk)
    
    dut.k_value.value = 4
    dut.fragment_count.value = 2
    await RisingEdge(dut.clk)
    
    dut.input_done.value = 1
    await RisingEdge(dut.clk)
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    result = int(dut.total_distance.value)
    dut._log.info(f"Result: {result}")
    assert result == 6, f"Expected 6, got {result}"
    
    # Reset
    dut.start.value = 0
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case 3: Edge case with k=0
    dut._log.info("Test Case 3: [0, 0, 1] -> Expected: 0")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    
    dut.k_value.value = 0
    dut.fragment_count.value = 2
    dut.input_done.value = 0
    await RisingEdge(dut.clk)
    
    dut.k_value.value = 1
    dut.fragment_count.value = 1
    await RisingEdge(dut.clk)
    
    dut.input_done.value = 1
    await RisingEdge(dut.clk)
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    result = int(dut.total_distance.value)
    dut._log.info(f"Result: {result}")
    assert result == 0, f"Expected 0, got {result}"
    
    dut._log.info("All tests completed!")

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases and boundary conditions"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test with large k values (scaled)
    dut._log.info("Edge Case: Large k values (scaled)")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    
    dut.k_value.value = 50
    dut.fragment_count.value = 3
    dut.input_done.value = 0
    await RisingEdge(dut.clk)
    
    dut.input_done.value = 1
    await RisingEdge(dut.clk)
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    result = int(dut.total_distance.value)
    dut._log.info(f"Result for [50,50,50]: {result}")
    
    # Test with mixed values
    dut.start.value = 0
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    dut._log.info("Edge Case: Mixed values [5, 0, 5, 0]")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    
    dut.k_value.value = 5
    dut.fragment_count.value = 2
    dut.input_done.value = 0
    await RisingEdge(dut.clk)
    
    dut.k_value.value = 0
    dut.fragment_count.value = 2
    await RisingEdge(dut.clk)
    
    dut.input_done.value = 1
    await RisingEdge(dut.clk)
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    result = int(dut.total_distance.value)
    dut._log.info(f"Result for [5,0,5,0]: {result}")
    
    dut._log.info("All edge case tests completed!")