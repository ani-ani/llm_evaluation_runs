import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_abbb_matcher(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.valid.value = 0
        dut.last.value = 0
        await RisingEdge(dut.clk)

    test_cases = [
        ("ac", 0),
        ("dc", 0),
        ("abbbba", 1),
        ("caacabbb", 1),
        ("aabbccdd", 0),
        ("abababab", 0)
    ]

    passed = 0
    await reset()

    for string, expected in test_cases:
        await reset()
        any_match = 0

        for i, c in enumerate(string):
            dut.char.value = ord(c)
            dut.valid.value = 1
            if i == len(string)-1:
                dut.last.value = 1
            await RisingEdge(dut.clk)
            dut.valid.value = 0
            dut.last.value = 0

            # Check combinatorial detection
            if dut.match.value == 1:
                any_match = 1

        # After last character, final result
        await RisingEdge(dut.clk)

        # Check if pattern was detected any time
        if (1 if any_match else 0) == expected:
            passed += 1
            dut._log.info(f"PASS: '{string}' -> {expected}")
        else:
            dut._log.error(f"FAIL: '{string}' -> {any_match}, expected {expected}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")