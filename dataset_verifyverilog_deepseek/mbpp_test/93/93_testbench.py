import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_power(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    test_cases = [
        # Base cases
        (0, 5, 0),   # 0^5 = 0
        (5, 0, 1),   # 5^0 = 1
        (7, 1, 7),   # 7^1 = 7
        # Normal cases
        (3, 4, 81),  # 3^4 = 81
        (2, 3, 8),   # 2^3 = 8
        (5, 5, 3125),# 5^5 = 3125
        (15, 2, 225),# Max base test
        (4, 7, 16384) # High exponent
    ]

    await reset()
    passed = 0

    for a_val, b_val, expected in test_cases:
        dut.a.value = a_val
        dut.b.value = b_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check result
        actual = dut.result.value
        if actual == expected:
            dut._log.info(f"PASS: {a_val}^{b_val} = {actual}")
            passed += 1
        else:
            dut._log.error(f"FAIL: {a_val}^{b_val} = {actual}, expected {expected}")

        # Insert pause between tests
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)

    dut._log.info(f"
TEST SUMMARY: {passed}/{len(test_cases)} tests passed")
