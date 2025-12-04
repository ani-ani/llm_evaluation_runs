import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_maze(dut):
    """Main test for maze escape module"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases: (grid_flattened, expected_time, expected_impossible)
    # Flattened grid format: 16 cells, each 2 bits:
    #   00 = wall, 01 = open, 10 = Joe, 11 = fire
    test_cases = [
        # Sample Input 1: 4x4 maze (output 3)
        # ####
        # #JF#
        # #..#
        # #..#
        (
            0b00_00_00_00_00_10_11_00_00_01_01_00_00_01_01_00,
            3,
            0
        ),
        # Sample Input 2: 3x3 maze (IMPOSSIBLE)
        # ###
        # #J.
        # #.F
        (
            0b00_00_00_00_00_10_01_00_00_01_11_00_00_00_00_00,
            0,
            1
        ),
        # Edge case: Joe starts on edge
        (
            0b10_01_01_00_01_00_00_00_00_00_00_00_00_00_00_00,
            0,
            0
        )
    ]

    passed = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    for grid, expected_t, expected_imp in test_cases:
        dut.grid_i.value = grid
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait until done or timeout 
        for _ in range(20):
            if dut.done_o.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            dut._log.error("Test timeout!")
            continue

        if expected_imp:
            if dut.impossible_o.value != 1:
                dut._log.error(f"Test failed: Expected IMPOSSIBLE but got time {dut.time_o.value}")
            else:
                passed += 1
        else:
            if dut.impossible_o.value == 1:
                dut._log.error(f"Test failed: Expected time {expected_t} but got IMPOSSIBLE")
            elif dut.time_o.value != expected_t:
                dut._log.error(f"Test failed: Got time {dut.time_o.value}, expected {expected_t}")
            else:
                passed += 1

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
