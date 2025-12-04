import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.binary import BinaryValue

def make_grid(cells):
    grid = np.zeros((8,8), dtype=np.int32)
    for i in range(min(8, len(cells))):
        for j in range(min(8, len(cells[0]))):
            c = cells[i][j]
            if c in '123':
                grid[i][j] = (int(c) << 1) | 1  # {state, 1}
            elif c == '.':
                grid[i][j] = 1 << 0  # road allowed
            else: # '#'
                grid[i][j] = 0
    return grid.flatten()

@cocotb.test()
async def test_three_states(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (adapted to 8x8 grid)
    test_cases = [
        (
            [
                '11..2',
                '#..22',
                '#.323',
                '.#333'
            ], 2
        ),
        (
            ['1#2#3'], -1
        ),
        (
            [
                '#2#',
                '1.3',
                '1.#'
            ], 1
        ),
        (
            ['12#3'], -1
        )
    ]
    
    passed = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    for grid_data, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load grid data (pad to 8x8)
        flat_grid = make_grid(grid_data)
        for i in range(64):
            dut.grid[i//8][i%8].value = flat_grid[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        expected_val = expected if expected != -1 else 255
        if dut.result.value == expected_val:
            passed += 1
            dut._log.info("Test passed")
        else:
            dut._log.error(f"Test failed: Expected {expected_val}, got {dut.result.value}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
