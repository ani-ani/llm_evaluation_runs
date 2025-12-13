import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_modp(dut):
    # Clock generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        (3, 5, 3),
        (0, 101, 1),
        (3, 11, 8),
        (100, 101, 1),
        (30, 5, 4),
        (31, 5, 3),
        (16, 17, 1),  # 65536 mod 17 = 1
        (15, 32768, 32768)  # Edge case - 32768 mod 32768 = 0
    ]

    passed = 0
    total = len(test_cases)

    for n, p, expected in test_cases:
        # Reset state machine
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Apply inputs
        dut.n.value = n
        dut.p.value = p
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check result
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: 2^{n} mod {p} = {expected}")
        else:
            dut._log.error(f"FAIL: 2^{n} mod {p} = {dut.result.value} (expected {expected})")

        await RisingEdge(dut.clk)  # Clear done signal

    dut._log.info(f"
SUMMARY: {passed}/{total} tests passed")
    assert passed == total