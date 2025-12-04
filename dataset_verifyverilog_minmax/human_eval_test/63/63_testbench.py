import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_fibfib(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (n, expected)
    test_cases = [
        (1, 0),
        (2, 1),
        (5, 4),
        (8, 24),
        (10, 81),
        (12, 274),
        (14, 927),
        (15, 1705)
    ]

    passed = 0
    for n_val, expected in test_cases:
        # Apply input
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done signal
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check result
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: fibfib({n_val}) = {dut.result.value}")
        else:
            dut._log.error(f"FAIL: fibfib({n_val}) = {dut.result.value}, expected {expected}")

        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Show summary
    dut._log.info(f"
TEST SUMMARY: {passed}/{len(test_cases)} tests passed")
