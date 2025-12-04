import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_median(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (padded to 8 elements with zeros)
    test_cases = [
        ([1, 12, 15, 26, 38, 0, 0, 0], [2, 13, 17, 30, 45, 0, 0, 0], 5, 32),  # 16.0 * 2
        ([2, 4, 8, 9, 0, 0, 0, 0], [7, 13, 19, 28, 0, 0, 0, 0], 4, 17),        # 8.5 * 2
        ([3, 6, 14, 23, 36, 42, 0, 0], [2, 18, 27, 39, 49, 55, 0, 0], 6, 50)   # 25.0 * 2
    ]

    passed = 0
    for arr1, arr2, size, expected in test_cases:
        # Load inputs
        for i in range(8):
            dut.arr1[i].value = arr1[i]
            dut.arr2[i].value = arr2[i]
        dut.n.value = size

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        await ClockCycles(dut.clk, size + 2)

        # Verify
        if dut.done.value == 1 and dut.med_sum.value == expected:
            passed += 1
            dut._log.info(f"PASS: Size={size} Result={dut.med_sum.value} Expected={expected}")
        else:
            dut._log.error(f"FAIL: Size={size} Got={dut.med_sum.value} Expected={expected}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")