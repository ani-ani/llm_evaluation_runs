import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_max_bling(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    test_cases = [
        (4, 0, 1, 0, 0, 0, 300),
        (5, 0, 1, 0, 1, 0, 1900),
        (6, 0, 1, 1, 0, 0, 2300),
        (8, 399, 0, 0, 0, 0, 399),
        (1, 400, 0, 0, 0, 0, 500)
    ]

    passed = 0
    for tc in test_cases:
        d, b, f, t0, t1, t2, expected = tc
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Apply inputs
        dut.days_remaining.value = d
        dut.initial_bling.value = b
        dut.initial_fruits.value = f
        dut.t0.value = t0
        dut.t1.value = t1
        dut.t2.value = t2
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for processing
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check output
        if dut.max_bling.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: d={d}, b={b}, f={f}, t0={t0}, t1={t1}, t2={t2}. Got {dut.max_bling.value}, expected {expected}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")