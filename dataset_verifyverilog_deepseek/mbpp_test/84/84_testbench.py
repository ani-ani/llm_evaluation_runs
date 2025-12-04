import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_newman(dut):
    # Known values (max n=16 to fit 4-bit output)
    test_vectors = [
        (1, 1),
        (2, 1),
        (3, 2),
        (4, 2),
        (5, 3),
        (6, 4),
        (7, 4),
        (8, 5),
        (9, 5),
        (10, 6)
    ]

    # Clock setup
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for n, expected in test_vectors:
        # Apply input
        dut.n_in.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check result
        if dut.result.value == expected:
            dut._log.info(f"PASS: P({n}) = {int(dut.result.value)}")
            passed += 1
        else:
            dut._log.error(f"FAIL: P({n}) = {int(dut.result.value)} (expected {expected})")

        await RisingEdge(dut.clk)  # Wait one cycle between tests

    dut._log.info(f"
SUMMARY: {passed}/{len(test_vectors)} tests passed")