import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_remove_parentheses(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0

    # Reset system
    await reset()

    # Test cases (string input as byte arrays padded with nulls)
    test_cases = [
        # Original: "python (chrome)"
        (b'python (chrome)\\0\\0\\0', b'python\\0\\0\\0\\0\\0\\0'),
        # Original: "string(.abc)"
        (b'string(.abc)\\0\\0\\0\\0', b'string\\0\\0\\0\\0\\0\\0\\0'),
        # Original: "alpha(num)"
        (b'alpha(num)\\0\\0\\0\\0\\0', b'alpha\\0\\0\\0\\0\\0\\0\\0'),
        # Edge case: empty parentheses
        (b'empty() test\\0\\0', b'empty test\\0\\0\\0\\0'),
        # Edge case: nested (considered invalid but handled)
        (b'A(B(C))D\\0\\0\\0\\0', b'AD\\0\\0\\0\\0\\0\\0\\0\\0')
    ]

    passed = 0
    total = len(test_cases)

    for instr, expected in test_cases:
        # Setup input
        dut.str_in.value = int.from_bytes(instr.ljust(16, b'\\0'), 'big')
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Get result
        result_bytes = dut.str_out.value.buff[::-1]  # Convert to bytes
        expected_bytes = expected.ljust(16, b'\\0')

        if result_bytes == expected_bytes:
            dut._log.info(f"PASS: {instr} -> {expected}")
            passed += 1
        else:
            dut._log.error(f"FAIL: {instr} => {result_bytes}, expected {expected_bytes}")

        # Wait a cycle before next test
        await RisingEdge(dut.clk)

    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")