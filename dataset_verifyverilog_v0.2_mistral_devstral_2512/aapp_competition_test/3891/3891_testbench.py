import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_black_square_center(dut):
    """Test the black_square_center module with various grid configurations."""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.cell_valid.value = 0
    dut.cell_is_black.value = 0
    dut.row_index.value = 0
    dut.col_index.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to run a test case
    async def run_test(grid):
        n = len(grid)
        m = len(grid[0]) if n > 0 else 0
        
        # Start the scan
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Drive cells in row-major order
        # For this test, we assume the DUT processes 32 cells total (8x8) 
        # or we can just drive valid cells for the actual grid size
        # Let's assume max 8x8 = 64 cells for the test logic
        
        for i in range(n):
            for j in range(m):
                dut.cell_valid.value = 1
                dut.row_index.value = i
                dut.col_index.value = j
                dut.cell_is_black.value = 1 if grid[i][j] == 'B' else 0
                await RisingEdge(dut.clk)
        
        # Send invalid data to finish (or drive remaining cycles if DUT expects fixed cycles)
        # The problem description implies tracking min/max during valid black cells.
        # Let's assume the DUT processes exactly 32 cycles or we drive 32 cycles for the testbench
        # to match the "assume 8x8 grid" logic in the prompt.
        
        # However, the prompt says "wait for valid". 
        # Let's drive 32 cycles to cover an 8x8 grid fully for the testbench logic.
        
        for _ in range(32 - (n * m)):
            dut.cell_valid.value = 0
            dut.cell_is_black.value = 0
            await RisingEdge(dut.clk)
            
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 50:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if not dut.done.value:
            raise TestFailure("Done signal did not go high within timeout")
            
        # Read results
        row = int(dut.center_row.value)
        col = int(dut.center_col.value)
        
        return row, col
    
    # Test Case 1: 5x6 grid, center at (2,4) [1-based] or (1,3) [0-based]
    # Input:
    # WWBBBW
    # WWBBBW
    # WWBBBW
    # WWWWWW
    # WWWWWW
    # Min R=1, Max R=3. Center R = (1+3)/2 = 2. -> Correct.
    # Min C=2, Max C=4. Center C = (2+4)/2 = 3. -> Wait, expected output is 2 4.
    # Output format is 1-based.
    # Black cells are at row 0,1,2 (indices) and col 2,3,4 (indices).
    # Min Row: 0, Max Row: 2 -> Avg (0+2)/2 = 1. +1 = 2.
    # Min Col: 2, Max Col: 4 -> Avg (2+4)/2 = 3. +1 = 4.
    # Correct.
    
    grid1 = [
        "WWBBBW",
        "WWBBBW",
        "WWBBBW",
        "WWWWWW",
        "WWWWWW"
    ]
    row, col = await run_test(grid1)
    if row != 2 or col != 4:
        raise TestFailure(f"Test 1 Failed: Expected (2, 4), Got ({row}, {col})")
    dut._log.info(f"Test 1 Passed: ({row}, {col})")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: 3x3 grid, single black cell at (1,0)
    # Input:
    # WWW
    # BWW
    # WWW
    # Min R=1, Max R=1 -> Avg 1. +1 = 2.
    # Min C=0, Max C=0 -> Avg 0. +1 = 1.
    # Expected: 2 1
    
    grid2 = [
        "WWW",
        "BWW",
        "WWW"
    ]
    row, col = await run_test(grid2)
    if row != 2 or col != 1:
        raise TestFailure(f"Test 2 Failed: Expected (2, 1), Got ({row}, {col})")
    dut._log.info(f"Test 2 Passed: ({row}, {col})")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 3: 3x3 grid, full black
    # Input:
    # BBB
    # BBB
    # BBB
    # Min R=0, Max R=2 -> Avg 1. +1 = 2.
    # Min C=0, Max C=2 -> Avg 1. +1 = 2.
    # Expected: 2 2
    
    grid3 = [
        "BBB",
        "BBB",
        "BBB"
    ]
    row, col = await run_test(grid3)
    if row != 2 or col != 2:
        raise TestFailure(f"Test 3 Failed: Expected (2, 2), Got ({row}, {col})")
    dut._log.info(f"Test 3 Passed: ({row}, {col})")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 4: 1x1 grid, single black
    # Input: B
    # Min R=0, Max R=0 -> Avg 0. +1 = 1.
    # Min C=0, Max C=0 -> Avg 0. +1 = 1.
    # Expected: 1 1
    
    grid4 = [
        "B"
    ]
    row, col = await run_test(grid4)
    if row != 1 or col != 1:
        raise TestFailure(f"Test 4 Failed: Expected (1, 1), Got ({row}, {col})")
    dut._log.info(f"Test 4 Passed: ({row}, {col})")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 5: 5x10 grid, center at (3,8)
    # 5 rows, 10 cols.
    # Grid given:
    # WWWWBBBBB (cols 4-8 black)
    # ...
    # Min R=0, Max R=2. Avg=1. +1=2.
    # Min C=4, Max C=8. Avg=6. +1=7. 
    # Wait, test case output says 2 8.
    # Let's recheck test case 5 input:
    # 5 10
    # WWWWBBBBB (Wait, input has 9 chars? "WWWWWWWBBB" or similar?)
    # The JSON has "WWWWWWBBBW" for the 5x10 test case (last one in inputs).
    # Last input in JSON list: 
    # 5 10
    # WWWWWWBBBW (cols 6,7,8 are B, col 9 is W)
    # WWWWWWBBBW
    # WWWWWWBBBW
    # WWWWWWWWWW
    # WWWWWWWWWW
    # Min R=0, Max R=2. Avg 1. +1 = 2.
    # Min C=6, Max C=8. Avg 7. +1 = 8.
    # Expected output: 2 8. Correct.
    
    grid5 = [
        "WWWWWWBBBW",
        "WWWWWWBBBW",
        "WWWWWWBBBW",
        "WWWWWWWWWW",
        "WWWWWWWWWW"
    ]
    row, col = await run_test(grid5)
    if row != 2 or col != 8:
        raise TestFailure(f"Test 5 Failed: Expected (2, 8), Got ({row}, {col})")
    dut._log.info(f"Test 5 Passed: ({row}, {col})")
    
    dut._log.info("All tests passed!")
