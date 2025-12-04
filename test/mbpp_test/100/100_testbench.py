import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_palindrome(dut):
    # Clock setup (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (input, expected output)
    test_cases = [
        (99, 101),
        (1221, 1331),
        (120, 121),
        (65436, 65556),  # Edge case near 16-bit max
        (0, 1)           // Boundary test
    ]

    passed = 0

    async def reset():
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.num.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    await reset()

    for num_in, expected in test_cases:
        # Apply input
        dut.num.value = num_in
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check result
        result = dut.palindrome.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {num_in} → {result}")
        else:
            dut._log.error(f"FAIL: {num_in} got {result}, expected {expected}")

        # Reset for next test
        await reset()

    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)
