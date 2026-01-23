import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

@cocotb.test()
async def test_optimal_probability(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.p_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: n=2, p=[0.1, 0.2] -> Expected 0.26
    # 0.1 -> 25/256, 0.2 -> 51/256
    # Target result in Q16.16: 0.26 * 65536 = 17039
    dut.n.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed sorted inputs (descending)
    dut.p_in.value = 51  # 0.2
    await RisingEdge(dut.clk)
    dut.p_in.value = 25  # 0.1
    await RisingEdge(dut.clk)
    
    # Wait for processing
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    result_val = int(dut.result.value)
    # Allow tolerance
    assert abs(result_val - 17039) < 50, f"Test 1 Failed: {result_val/65536.0} != 0.26"
    dut._log.info(f"Test 1 passed: {result_val/65536.0}")

    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: n=4, p=[0.1, 0.2, 0.3, 0.8] -> Expected 0.8
    # 0.8 -> 204/256, 0.3 -> 76/256, 0.2 -> 51/256, 0.1 -> 25/256
    # Target result: 0.8 * 65536 = 52428
    dut.n.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.p_in.value = 204 # 0.8
    await RisingEdge(dut.clk)
    dut.p_in.value = 76  # 0.3
    await RisingEdge(dut.clk)
    dut.p_in.value = 51  # 0.2
    await RisingEdge(dut.clk)
    dut.p_in.value = 25  # 0.1
    await RisingEdge(dut.clk)

    for _ in range(5):
        await RisingEdge(dut.clk)

    result_val = int(dut.result.value)
    assert abs(result_val - 52428) < 50, f"Test 2 Failed: {result_val/65536.0} != 0.8"
    dut._log.info(f"Test 2 passed: {result_val/65536.0}")

    # Test Case 3: n=3, p=[0.2, 0.2, 0.2] -> Expected 0.384 (approx)
    # Target: 0.384 * 65536 = 25165
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.n.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    dut.p_in.value = 51 # 0.2
    await RisingEdge(dut.clk)
    dut.p_in.value = 51
    await RisingEdge(dut.clk)
    dut.p_in.value = 51
    await RisingEdge(dut.clk)

    for _ in range(5):
        await RisingEdge(dut.clk)

    result_val = int(dut.result.value)
    assert abs(result_val - 25165) < 50, f"Test 3 Failed: {result_val/65536.0} != 0.384"
    dut._log.info(f"Test 3 passed: {result_val/65536.0}")