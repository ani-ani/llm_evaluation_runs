import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import numpy as np

@cocotb.test()
async def test_xray_optimal_energies(dut):
    """Test x-ray optimal energy selection module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k_wr.value = 0
    dut.k_data.value = 0
    dut.bin_index.value = 0
    dut.n.value = 0
    dut.m.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: n=3, m=2, k=[3,1,1]
    dut._log.info("Test Case 1: n=3, m=2, k=[3,1,1]")
    dut.n.value = 3
    dut.m.value = 2
    await RisingEdge(dut.clk)
    
    # Load k array
    for i, k_val in enumerate([3, 1, 1]):
        dut.bin_index.value = i + 1  # 1-based indexing
        dut.k_data.value = k_val
        dut.k_wr.value = 1
        await RisingEdge(dut.clk)
    dut.k_wr.value = 0
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 3000 cycles to be safe)
    timeout = 0
    while not dut.done.value and timeout < 3000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Computation did not complete in time"
    assert dut.valid.value == 1, "Result not valid"
    
    # Read result (Q32.0 format, so divide by 2^32)
    result_raw = int(dut.min_sum.value)
    result = result_raw / (2**32)
    expected = 0.5
    
    dut._log.info(f"Result: {result}, Expected: {expected}")
    assert abs(result - expected) < 0.01, f"Result mismatch: {result} vs {expected}"
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 2: n=5, m=2, k=[8,0,5,13,2]
    dut._log.info("Test Case 2: n=5, m=2, k=[8,0,5,13,2]")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 5
    dut.m.value = 2
    await RisingEdge(dut.clk)
    
    # Load k array
    for i, k_val in enumerate([8, 0, 5, 13, 2]):
        dut.bin_index.value = i + 1
        dut.k_data.value = k_val
        dut.k_wr.value = 1
        await RisingEdge(dut.clk)
    dut.k_wr.value = 0
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 3000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Computation did not complete in time"
    assert dut.valid.value == 1, "Result not valid"
    
    # Read result
    result_raw = int(dut.min_sum.value)
    result = result_raw / (2**32)
    expected = 6.55
    
    dut._log.info(f"Result: {result}, Expected: {expected}")
    assert abs(result - expected) < 0.05, f"Result mismatch: {result} vs {expected}"
    
    dut._log.info("All tests passed!")
