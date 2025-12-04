import cocotb
from cocotb.triggers import RisingEdge, Timer\\
@cocotb.test()
async def test_tram_explosion(dut):
    # Clock generation
    clock = cocotb.clock.Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
\\
    # Test cases (scaled grid size)
    test_grids = [
        (4, 4, [
            2,1,0,2,  # .LX. translated to values: 2=L, 1=X, 0=.
            0,1,0,0,  # .X.. 
            0,0,0,0,  # .... 
            2,1,0,0   # .L..
        ], 1),
        (4, 4, [
            0,1,2,1,  # .XLX
            0,1,0,0,  # .X..
            0,0,0,2,  # ...L
            0,1,0,0   # .X..
        ], 2)
    ]\\
    passed = 0
    dut._log.info("Starting tests")
\\
    for (rows, cols, grid_vec, expected) in test_grids:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
\\
        # Load inputs
        dut.rows.value = rows
        dut.cols.value = cols
        for i in range(16):
            dut.grid[i].value = grid_vec[i] if i < len(grid_vec) else 0
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
\\
        # Wait for completion (max 20 cycles)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            dut._log.error("Timeout waiting for done")
            continue\\
        # Check output
        if dut.explosions.value == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: Expected {expected}, got {dut.explosions.value}")
    dut._log.info(f"{passed}/{len(test_grids)} tests passed")
    assert passed == len(test_grids)