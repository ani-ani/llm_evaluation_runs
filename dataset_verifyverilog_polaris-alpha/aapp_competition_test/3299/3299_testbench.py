import cocotb
from cocotb.triggers import Timer
import numpy as np

@cocotb.test()
async def test_checkerboard(dut):
    # Pre-filled test cases using known solutions
    test_grids = [
        # Case 1: Valid grid (sum=88)
        [[1,2,3,4],[3,4,5,6],[5,6,7,8],[7,8,9,10]],
        # Case 2: Invalid grid (due to parity conflict)
        [[1,2,3,4],[3,4,5,6],[5,4,7,8],[7,8,9,10]],
        # Case 3: Minimal valid 2x3 grid (padded with 1's to 4x4)
        [[1,2,3,1],[4,5,6,1],[1,1,1,1],[1,1,1,1]]
    ]
    expected = [1, 0, 1] # Validity results only
    passed = 0
    
    for i, grid in enumerate(test_grids):
        for row in range(4):
            for col in range(4):
                dut.grid[row][col].value = grid[row][col]
        await Timer(1, units='ns')
        if dut.valid.value == expected[i]:
            passed += 1
        else:
            actual_sum = np.array(grid).sum() # Calculate sum in testbench
            dut._log.error("Test %d failed: valid=%d (expected %d), grid_sum=%d" % (i+1, dut.valid.value, expected[i], actual_sum))
    dut._log.info("%d/%d checks passed" % (passed, len(test_grids)))