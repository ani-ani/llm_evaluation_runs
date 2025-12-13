import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_min_energy(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled to 4x4 grids)
    test_cases = [
        (
            4, 4,
            [
                [0,0,0,0],  # E row
                [1,2,3,4],
                [5,4,-2,2],
                [8,9,-3,1],
            ],
            0b1111, 0b1111,
            17  # Scaled expected
        ),
        (
            2, 2,
            [
                [0,0],  # E
                [-5,9],
            ],
            0b11, 0b11,
            5
        )
    ]

    passed = 0
    for R, C, grid, E_mask, S_mask, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.R.value = R
        dut.C.value = C
        dut.E_mask.value = E_mask
        dut.S_mask.value = S_mask
        for i in range(16):
            if i < R*C:
                row = i // C
                col = i % C
                dut.grid[i].value = grid[row][col] if grid[row][col] >=0 else (1 << 4) | abs(grid[row][col])
            else:
                dut.grid[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        timeout = 8*R*C + 10
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1

        assert timeout > 0, "Simulation timed out"
        
        # Check result
        if dut.min_energy.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: Expected {expected}, got {dut.min_energy.value}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
