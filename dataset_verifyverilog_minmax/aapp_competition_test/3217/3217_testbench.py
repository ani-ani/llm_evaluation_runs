import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_enclosure(dut):
    clock = Clock(dut.clk, 10, units="ns") # 100MHz clock
    cocotb.start_soon(clock.start())
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (scaled to 4x4x4 grid)
    test_cases = [
        (1, [[0,0,0]], 6), # Single cell
        (2, [[0,0,0], [0,0,1]], 10), # Two adjacent cells
        (3, [[0,0,0], [0,0,1], [0,1,1]], 14) # Three cells forming L-shape
    ]

    passed = 0
    for n, cells, expected in test_cases:
        # Format cell coordinates
        dut.num_cells.value = n
        for i in range(8):
            if i < n:
                x,y,z = cells[i]
                dut.cell_coords[i].value = (z << 4) | (y << 2) | x
            else:
                dut.cell_coords[i].value = 0
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for done signal (max 80 cycles)
        timeout = 100
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        if timeout == 0:
            dut._log.error("Timeout waiting for done")
        # Verify result
        panels = dut.panels.value.integer
        if panels == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: {n} cells got {panels}, expected {expected}")
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    # Display results
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
