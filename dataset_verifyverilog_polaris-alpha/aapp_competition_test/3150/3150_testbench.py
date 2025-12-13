import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import numpy as np

def pack_trench(x1, y1, x2, y2):
    return (x1 << 30) | (y1 << 20) | (x2 << 10) | y2

@cocotb.test()
async def test_guard_placements(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Test case data: (num_trenches, trench_list, expected_output)
    test_cases = [
        (6, [
            (0, 0, 1, 0), (0, 0, 0, 1), (1, 0, 1, 1),
            (0, 1, 1, 1), (0, 0, 1, 1), (1, 0, 0, 1)
        ], 8),
        (4, [
            (5, 1, 7, 1), (1, 1, 5, 1), (4, 0, 4, 4), (7, 0, 3, 4)
        ], 1),
        (3, [
            (2, 2, 3, 2), (3, 2, 3, 3), (3, 3, 2, 3)
        ], 0)
    ]
    passed = 0
    for (n_trenches, trenches, expected) in test_cases:
        # Reset and initial setup
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        # Pack trench data
        packed = 0
        for i, (x1, y1, x2, y2) in enumerate(trenches):
            packed_trench = pack_trench(x1, y1, x2, y2)
            packed = packed | (packed_trench << (40*i))
        # Apply inputs
        dut.num_trenches.value = n_trenches
        dut.trenches.value = packed
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        # Check result
        if dut.result_count.value == expected:
            passed += 1
        else:
            dut._log.error("Test failed: Expected %d, got %d" % (expected, dut.result_count.value))
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")