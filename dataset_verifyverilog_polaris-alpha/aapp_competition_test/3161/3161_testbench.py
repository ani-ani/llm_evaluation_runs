import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_josip(dut):
    # Generate clock (100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (N=4 and N=8)
    test_cases = [
        (4, [
            "0001",
            "0001",
            "0011",
            "1110"
        ], 1),
        (4, [
            "1111",
            "1111",
            "1111",
            "1111"
        ], 6)
    ]

    passed = 0
    for n, grid, expected_diff in test_cases:
        # Convert to flattened format
        flat = 0
        for row in grid:
            for c in row:
                flat = (flat << 1) | (1 if c == '1' else 0)
        flat <<= (64 - n*n)  # Align to MSB

        # Reset module
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Start computation
        dut.target_image.value = flat
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check results
        if dut.min_difference.value == expected_diff:
            passed += 1
        else:
            dut._log.error("Diff mismatch: %d != expected %d" % (dut.min_difference.value, expected_diff))

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")