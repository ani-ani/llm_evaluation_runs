import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_stellar_counter(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Load grid helper function
    async def load_grid(grid):
        dut.start.value = 0
        for row in range(16):
            for col in range(16):
                dut.grid_row.value = row
                dut.grid_col.value = col
                dut.pixel_value.value = grid[row][col] if row < len(grid) and col < len(grid[0]) else 0
                dut.pixel_valid.value = 1
                await RisingEdge(dut.clk)
        dut.pixel_valid.value = 0

    # Test cases adapted to 5x6 grids (padded to 16x16 with zeros)
    test_grids = [
        [[0x0000, 0xFFFF, 0x0000, 0x0000, 0x0000, 0x0000],
         [0xFFFF, 0xFFFF, 0x0000, 0xFFFF, 0xFFFF, 0x0000],
         [0x0000, 0x0000, 0x0000, 0xFFFF, 0x0000, 0x0000],
         [0x0000, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0x0000],
         [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000]],
        [[0x1C71, 0x1C71, 0x1C71, 0x0000, 0x0000, 0x0000],
         [0x1C71, 0x1C71, 0x1C71, 0x0000, 0x0000, 0x0000],
         [0x1C71, 0x1C71, 0x1C71, 0x1C71, 0x1C71, 0x1C71],
         [0x0000, 0x0000, 0x0000, 0x1C71, 0x1C71, 0x1C71],
         [0x0000, 0x0000, 0x0000, 0x1C71, 0x1C71, 0x1C71]]
    ]
    expected = [2, 2]

    await reset()
    passed = 0

    for i, grid in enumerate(test_grids):
        await load_grid(grid)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 400 cycles)
        cycles = 0
        while not dut.done.value and cycles < 400:
            await RisingEdge(dut.clk)
            cycles += 1

        if dut.done.value:
            if dut.star_count.value == expected[i]:
                passed += 1
            else:
                dut._log.error(f"Test {i} failed: Got {dut.star_count.value}, expected {expected[i]}")
        else:
            dut._log.error(f"Test {i} timed out after 400 cycles")

        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_grids)} tests passed")