import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_odd_even_sum(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        # (input_list, expected_sum)
        ([5, 8, 7, 1], 12),  # Original test
        ([3, 3, 3, 3, 3], 9),
        ([30, 13, 24, 321], 0),
        ([5, 9], 5),
        ([2, 4, 8], 0),
        ([30, 13, 23, 32], 23),
        ([3, 13, 2, 9], 3)
    ]

    passed = 0

    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for data_list, expected in test_cases:
        dut.start.value = 0
        dut.sum_result.value = 0

        # Apply inputs
        for idx, value in enumerate(data_list):
            dut.index.value = idx
            dut.data.value = value
            await RisingEdge(dut.clk)

        # Start processing
        dut.count.value = len(data_list)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while dut.done.value == 0:
            await RisingEdge(dut.clk)

        # Check result
        if dut.sum_result.value == expected:
            passed += 1
            dut._log.info(f"PASS: {data_list} -> {expected}")
        else:
            dut._log.error(f"FAIL: {data_list} -> {int(dut.sum_result.value)}, expected {expected}")

        # Wait 1 cycle between tests
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")