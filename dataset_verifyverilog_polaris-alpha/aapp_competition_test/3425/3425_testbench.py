import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_queen_module(dut):
    # Create 50MHz clock
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled to 4x4 boards)
    test_boards = [
        (0b1111_1111_1111_1111, 5, 6),   # Full 4x4 (max queens=5)
        (0b1111_0101_1111_1111, 4, 12),  # With broken center cells
        (0b1010_0101_1010_0100, 3, 8)    # Highly fractured board
    ]

    passed = 0
    dut._log.info("
----- Starting tests -----")
    for i, (board, exp_max, exp_ways) in enumerate(test_boards):
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Apply test input
        dut.board_layout.value = board
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Verify outputs
        if dut.max_queens.value == exp_max and dut.num_ways.value == exp_ways:
            passed += 1
            dut._log.info(f"Test {i} passed")
        else:
            dut._log.error(f"Test {i} FAILED: Got max={dut.max_queens.value} ways={int(dut.num_ways.value)}, Expected max={exp_max} ways={exp_ways}")

    # Final report
    total = len(test_boards)
    dut._log.info(f"
Test summary: {passed}/{total} tests passed")
    assert passed == total