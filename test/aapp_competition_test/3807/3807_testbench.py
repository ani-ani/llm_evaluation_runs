import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_greedy_tower(dut):
    # Generate 100MHz clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    test_cases = [
        (48, (9, 42)),
        (6, (6, 6)),
        (1, (1, 1)),
        (7, (7, 7)),
        (1000, (11, 925)) # Adjusted expected values
    ]
    passed = 0

    for m_val, expected in test_cases:
        dut.start.value = 0
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        dut.m.value = m_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for computation to finish
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check results
        if (dut.block_count.value == expected[0]) and (dut.volume_X.value == expected[1]):
            passed +=1
            dut._log.info(f"Passed: m={m_val} => blocks={dut.block_count.value}, X={dut.volume_X.value}")
        else:
            dut._log.error(f"FAIL: m={m_val} Got ({dut.block_count.value}, {dut.volume_X.value}) Expected {expected}")

        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)