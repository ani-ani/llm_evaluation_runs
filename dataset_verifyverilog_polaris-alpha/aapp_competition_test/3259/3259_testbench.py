import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_alien_box_controller(dut):
    # Generate clock (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    async def reset():"""Reset the device"""
        dut.rst_n.value = 0
        dut.input_valid.value = 0
        await ClockCycles(dut.clk, 5)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    await reset()
    passed = 0
    total_tests = 0
    
    # Test Case 1: Initial sum (all zeros)
    dut.input_valid.value = 1
    dut.query_type.value = 0
    dut.L.value = 1
    dut.R.value = 6
    await RisingEdge(dut.clk)
    dut.input_valid.value = 0
    
    # Wait for completion (max cycles)
    for _ in range(17):
        if dut.output_valid.value: break
        await RisingEdge(dut.clk)
    assert dut.output_valid.value, "Timeout on test 1"
    assert dut.sum_out.value == 0, "Test 1: Initial sum should be 0, got {dut.sum_out.value}".format(dut.sum_out.value)
    passed += 1
    total_tests += 1
    
    # Test Case 2: Update boxes 1-5 with A=1, B=2
    await RisingEdge(dut.clk)
    dut.input_valid.value = 1
    dut.query_type.value = 1
    dut.L.value = 1
    dut.R.value = 5
    dut.A.value = 1
    dut.B.value = 2
    await RisingEdge(dut.clk)
    dut.input_valid.value = 0
    
    # Wait for completion (5 boxes: 5+1 cycles)
    for _ in range(7):
        if dut.output_valid.value: break
        await RisingEdge(dut.clk)
    assert dut.output_valid.value, "Timeout on test 2"
    total_tests += 1
    passed += 1  # Type 1 has no output validation
    
    # Test Case 3: Sum boxes 1-6 (expected 3)
    await RisingEdge(dut.clk)
    dut.input_valid.value = 1
    dut.query_type.value = 0
    dut.L.value = 1
    dut.R.value = 6
    await RisingEdge(dut.clk)
    dut.input_valid.value = 0
    
    for _ in range(17):
        if dut.output_valid.value: break
        await RisingEdge(dut.clk)
    assert dut.output_valid.value, "Timeout on test 3"
    if dut.sum_out.value == 3:
        passed += 1
    else:
        dut._log.error("Test 3: Expected sum 3, got {}".format(dut.sum_out.value))
    total_tests += 1
    
    # Test Case 4: Sample Input 2 operations
    # Update 1-4 A=3,B=4
    await RisingEdge(dut.clk)
    dut.input_valid.value = 1
    dut.query_type.value = 1
    dut.L.value = 1
    dut.R.value = 4
    dut.A.value = 3
    dut.B.value = 4
    await RisingEdge(dut.clk)
    dut.input_valid.value = 0
    await ClockCycles(dut.clk, 6)  # 4 boxes updated +1
    assert dut.output_valid.value, "Test4a didn't complete"
    passed += 1
    total_tests += 1
    
    # Verify box 1: (1-1+1)*3 mod4 = 3
    await RisingEdge(dut.clk)
    dut.input_valid.value = 1
    dut.query_type.value = 0
    dut.L.value = 1
    dut.R.value = 1
    await RisingEdge(dut.clk)
    dut.input_valid.value = 0
    await ClockCycles(dut.clk, 3)
    assert dut.sum_out.value == 3, "Test4b: Box1 expected 3, got {}".format(dut.sum_out.value)
    passed += 1
    total_tests += 1
    
    # Summary
    dut._log.info(f"{passed}/{total_tests} tests passed")
    assert passed == total_tests, "Some tests failed"