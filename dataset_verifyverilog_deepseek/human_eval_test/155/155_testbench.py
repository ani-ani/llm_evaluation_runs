import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_counter(dut):
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
        (7, (0, 1)),
        (-78, (1, 1)),
        (123, (1, 2)),
        (0, (1, 0)),
        (32767, (2, 3)),
        (-2, (1, 0))
    ]

    await reset()
    passed = 0

    for (num, (exp_even, exp_odd)) in test_cases:
        dut.num.value = num
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait until processing completes
        while not dut.done.value:
            await RisingEdge(dut.clk)

        even = dut.even_count.value.integer
        odd = dut.odd_count.value.integer
        if even == exp_even and odd == exp_odd:
            passed += 1
            dut._log.info(f"PASS: num={num} counts=({even},{odd})")
        else:
            dut._log.error(f"FAIL: num={num} expected ({exp_even},{exp_odd}) got ({even},{odd})")

        await Timer(10, units='ns')

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)