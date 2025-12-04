import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_ludic(dut):
    # Test cases (n, expected_ludics)
    test_cases = [
        (10, [1, 2, 3, 5, 7]),
        (25, [1, 2, 3, 5, 7, 11, 13, 17, 23, 25]),
        (45, [1, 2, 3, 5, 7, 11, 13, 17, 23, 25, 29, 37, 41, 43])
    ]

    # Clock generator
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    passed = 0
    for (n_val, expected) in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Start computation
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for processing to start
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Collect output
        results = []
        await RisingEdge(dut.clk)  # Skip the done cycle
        for _ in range(n_val):
            if dut.valid.value:
                results.append(int(dut.out_value.value))
            await RisingEdge(dut.clk)
            if dut.done.value:
                break

        # Verify output
        filtered = [x for x in results if x != 0]
        if filtered == expected:
            dut._log.info(f"PASS: n={n_val} got {filtered}")
            passed += 1
        else:
            dut._log.error(f"FAIL: n={n_val} got {filtered}, expected {expected}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")