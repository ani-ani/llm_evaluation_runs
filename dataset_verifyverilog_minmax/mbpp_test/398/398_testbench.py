import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_digit_sum(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (padded to 8 elements)
    test_cases = [
        ([10,  2, 56,   0, 0, 0, 0, 0], 14),   # Original Test 1
        ([10, 20, -4,   5, -70, 0, 0, 0], 19), # Modified Test 3 (1+0 + 2+0 +4 +5 +7+0)
        ([127, -128, 0, 0, 0, 0, 0, 0], 19)    # Edge: 1+2+7 + 1+2+8 = 10+11
    ]

    passed = 0

    for numbers, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        for i in range(8):
            dut.numbers[i].value = numbers[i] if numbers[i] >= 0 else (256 + numbers[i])

        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Verify result
        if dut.total_sum.value == expected:
            passed += 1
            dut._log.info(f"PASS: {numbers} -> {dut.total_sum.value}")
        else:
            dut._log.error(f"FAIL: {numbers} -> {dut.total_sum.value}, expected {expected}")

        await Timer(10, units='ns')

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)