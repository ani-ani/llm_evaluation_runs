import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_sum_odd_squares(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    def q8_format(x):
        return int(x * (2**0)) & 0xFFFF  # Q8.0 format

    # Test cases (original adapted to integers)
    test_cases = [
        ([], 0),
        ([5, 4], 5*5),
        ([-10, -20, -30, 0,0,0,0,0], 0),
        ([-1, -2, 8, 0,0,0,0,0], 0),
        ([3, 5, 0,0,0,0,0,0], 3*3 + 5*5),
        ([1, 3, 2, 0, 0,0,0,0], 1*1 + 3*3),
        ([9, -2, 0,0,0,0,0,0], 9*9)
    ]

    passed = 0
    await reset()

    for inputs, expected in test_cases:
        # Pad inputs to 8 elements
        padded = list(inputs) + [0]*(8-len(inputs))
        dut.numbers.value = [q8_format(x) for x in padded]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait 8 cycles
        for _ in range(8):
            await RisingEdge(dut.clk)

        if dut.done.value == 1 and dut.sum.value == expected:
            passed += 1
            dut._log.info(f"PASS: {inputs} => {expected}")
        else:
            dut._log.error(f"FAIL: {inputs} => {dut.sum.value} (expected {expected})")

        await RisingEdge(dut.clk)
        dut._log.info(f"{passed}/{len(test_cases)} tests passed")
