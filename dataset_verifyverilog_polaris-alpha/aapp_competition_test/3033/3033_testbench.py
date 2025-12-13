import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_digit_solver(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        (10, 24, 38),
        (10, 11, 0),
        (4, 8, 22),
        (16, 10, 10),
        (2, 1, 1)
    ]

    await Timer(20, units="ns")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for (base, n_val, expected) in test_cases:
        dut.B.value = base
        dut.N.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 32 cycles)
        timeout = 32
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1

        if timeout == 0:
            dut._log.error("Test timed out")
            continue

        if expected == 0:
            if dut.impossible.value != 1:
                dut._log.error(f"Test failed: Base={base}, N={n_val} should be impossible")
            else:
                passed += 1
        else:
            if dut.X.value != expected:
                dut._log.error(f"Test failed: Base={base}, N={n_val} = {dut.X.value}, expected {expected}")
            else:
                passed += 1

    # Check impossible case explicitly
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")