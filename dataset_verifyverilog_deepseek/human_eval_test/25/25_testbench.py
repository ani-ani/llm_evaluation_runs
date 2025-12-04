import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_factorization(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    test_cases = [
        (2, [2]),
        (4, [2, 2]),
        (8, [2, 2, 2]),
        (3*19, [3, 19]),
        (3*19*3*19, [3, 3, 19, 19]),
        (70, [2, 5, 7])
    ]

    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_in.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for (input_val, expected) in test_cases:
        # Apply input
        dut.start.value = 1
        dut.n_in.value = input_val
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.valid.value:
            await RisingEdge(dut.clk)

        # Check results
        factors = [dut.factors[i].value for i in range(int(dut.factor_count.value))]
        error_msg = f"FAIL: {input_val} factors: {factors}, expected {expected}"
        assert list(factors) == expected, error_msg
        passed += 1
        dut._log.info(f"PASS: {input_val} factors: {factors}")
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
