import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_digit_sum(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        (1, 9, 5, 1, 5),
        (1, 100, 10, 9, 19),
        (100, 200, 3, 5, 102),
        (9995, 10005, 36, 1, 9999)  # Edge case test
    ]
    passed = 0

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for (A, B, S, exp_count, exp_smallest) in test_cases:
        # Apply inputs
        dut.A.value = A
        dut.B.value = B
        dut.S.value = S
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check results
        if dut.count.value == exp_count and dut.smallest_num.value == exp_smallest:
            passed += 1
        else:
            dut._log.error(f"Test failed: A={A}, B={B}, S={S}
              Got count={dut.count.value} (expected {exp_count}), smallest={dut.smallest_num.value} (expected {exp_smallest})")

        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)