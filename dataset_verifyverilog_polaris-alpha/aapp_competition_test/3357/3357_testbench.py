import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import math
import numpy as np

@cocotb.test()
async def test_sunlight(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset system
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Sample input (4 buildings)
    buildings = [
        (1, 1),  # Q16.16 expected: 9/12 * 180 = 135° visible
        (2, 2),  # 180 - 45 - 45 = 90° → 12h
        (3, 2),  # Same as above
        (4, 1)   # Mirror of first
    ]

    dut.num_buildings.value = 4
    for i in range(4):
        dut.x_pos[i].value = buildings[i][0] * 65536  # Q16.16
        dut.height[i].value = buildings[i][1] * 65536
    for i in range(4, 8):
        dut.x_pos[i].value = 0
        dut.height[i].value = 0

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for computation (60 cycles)
    for _ in range(60):
        await RisingEdge(dut.clk)

    assert dut.done.value == 1, "Done signal not asserted"

    # Check results in Q16.16 format
    expected = [9.0, 12.0, 12.0, 9.0]
    passed = 0
    for i in range(4):
        result_fp = dut.sunlight[i].value / 65536.0
        error_msg = f"Building {i}: {result_fp:.4f} ≠ {expected[i]:.1f}"
        assert abs(result_fp - expected[i]) < 0.1, error_msg
        passed += 1

    dut._log.info(f"{passed}/4 tests passed")