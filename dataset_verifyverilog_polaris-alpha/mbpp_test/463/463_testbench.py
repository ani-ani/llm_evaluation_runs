import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_max_product(dut):
    """Test max product subarray computation"""
    # Create 50MHz clock
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (padded to 8 elements with zeros)
    test_cases = [
        ([1, -2, -3, 0, 7, -8, -2, 0], 112),
        ([6, -3, -10, 0, 2, 0, 0, 0], 180),
        ([-2, -40, 0, -2, -3, 0, 0, 0], 80),
        ([ -1, -2, -3, -4, 0, 0, 0, 0], 24) \/\/ Extra test case
    ]

    passed = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for arr, expected in test_cases:
        # Flatten array input
        for i in range(8):
            dut.arr[i].value = arr[i] if i < len(arr) else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (10 cycles)
        await ClockCycles(dut.clk, 10)

        # Check result
        actual = dut.max_product.value.signed_integer
        if actual == expected:
            dut._log.info(f"PASS: {arr} -> {actual}")
            passed += 1
        else:
            dut._log.error(f"FAIL: {arr} -> {actual}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)