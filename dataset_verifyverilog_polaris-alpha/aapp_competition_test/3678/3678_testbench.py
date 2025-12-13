import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_loops(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        (6, [(1,1), (1,3), (2,2), (2,3), (3,1), (3,2)], True),  # Should be YES
        (3, [(1,1), (1,2), (2,1)], False),  # Should be NO
        (4, [(0,0), (0,1), (1,1), (1,0)], True),  # Small square (valid)
        (4, [(0,0), (1,1), (0,1), (1,0)], False)   # Diagonals crossing (invalid)
    ]

    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    passed = 0
    for (n, points, expected) in test_cases:
        # Apply points
        dut.start.value = 1
        dut.num_points.value = n
        await RisingEdge(dut.clk)
        dut.start.value = 0
        dut.point_valid.value = 1
        for (x,y) in points:
            dut.x_in.value = x
            dut.y_in.value = y
            await RisingEdge(dut.clk)
        dut.point_valid.value = 0

        # Wait for processing
        lat = 10 + 2*n
        await ClockCycles(dut.clk, lat)

        # Verify result
        if dut.done.value == 1 and dut.valid_loop.value == expected:
            passed += 1
        else:
            msg = f"Failed {n}-point case: expected {expected}, got {dut.valid_loop.value}
Points: {points}"
            dut._log.error(msg)
        # Reset between test cases
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await ClockCycles(dut.clk, 2)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
