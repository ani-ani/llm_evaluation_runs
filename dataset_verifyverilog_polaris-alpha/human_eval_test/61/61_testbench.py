import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_bracket_checker(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        ("()      ", 1),     # Valid (padded with spaces)
        ("(()())  ", 1),   # Valid
        (")(      ", 0),     # Invalid
        ("((((    ", 0),    # Invalid
        ("())()   ", 0)     # Invalid
    ]

    passed = 0

    async def do_test(brackets_str, expected):
        brackets = int.from_bytes(brackets_str.encode(), 'big')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        dut.brackets.value = brackets
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        for _ in range(8):
            await RisingEdge(dut.clk)

        if dut.done.value != 1:
            dut._log.error(f"Test failed: Done bit not set for {brackets_str}")
            return False

        if dut.result.value == expected:
            dut._log.info(f"PASS: {brackets_str} -> {expected}")
            return True
        else:
            dut._log.error(f"FAIL: {brackets_str} -> {dut.result.value}, expected {expected}")
            return False

    for brackets_str, expected in test_cases:
        if await do_test(brackets_str, expected):
            passed += 1

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)