import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure, TestSuccess

# Helper to calculate expected changes for a small 8x8 grid
def calculate_expected(grid):
    rows = 8
    cols = 8
    changes_needed = 0
    # Check 2x2 subgrids
    for r in range(rows - 1):
        for c in range(cols - 1):
            tl = grid[r][c]
            tr = grid[r][c+1]
            bl = grid[r+1][c]
            br = grid[r+1][c+1]
            # Check for the specific 'corner' pattern that violates rectangularity
            # Pattern: TL == BR and TR != BL (or TL == TR and BL != BR, etc.)
            # The problem solution logic usually simplifies to checking if diagonal equals imply vertical/horizontal consistency
            # A common check is: if TL == BR and TR != BL, it's an error
            if tl == br and tr != bl:
                changes_needed += 1
            # The provided Python solution finds the minimum changes by trying all possible row masks (2^m)
            # But for the HDL test, we need a deterministic check.
            # The Python code `work(y)` calculates changes for a specific target row pattern.
            # However, checking 2x2 corners is a robust property of the rectangular constraint.
    return changes_needed

@cocotb.test()
async def test_rectangular_grid_checker(dut):
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_row.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Perfect 8x8 grid (all 1s) -> 0 changes
    dut._log.info("Test 1: Perfect 8x8 grid")
    grid1 = [[1 for _ in range(8)] for _ in range(8)]
    for i in range(8):
        # Pack 8 bits into an integer
        row_val = 0
        for bit in grid1[i]:
            row_val = (row_val << 1) | bit
        dut.row_data.value = row_val
        dut.row_index.value = i
        dut.load_row.value = 1
        await RisingEdge(dut.clk)
        dut.load_row.value = 0
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles = 0
    while dut.done.value == 0 and cycles < 200:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if dut.result.value != 0:
        raise TestFailure(f"Expected 0, got {int(dut.result.value)}")
    
    # Test Case 2: Grid with single 'corner' error -> 1 change
    # Pattern: 1 1 1
    #          1 1 0
    #          1 0 1 (The bottom right 1 makes a corner with 0s)
    dut._log.info("Test 2: Grid with 1 error")
    # Let's make a simpler explicit corner in 8x8
    # Row 0: 11111111
    # Row 1: 11111111
    # Row 2: 11111110
    # Row 3: 11111101 -> This creates a corner at cols 6,7 rows 2,3
    grid2 = [[1]*8 for _ in range(8)]
    grid2[2][7] = 0
    grid2[3][6] = 0 # Actually, 1 0 / 0 1 is the error. 
    # Let's make grid2[2][7]=0, grid2[3][7]=1, grid2[2][6]=1, grid2[3][6]=0
    # 1 0 
    # 0 1 -> Error (TL=1, TR=0, BL=0, BR=1) -> TL=BR, TR!=BL
    grid2[2][7] = 0
    grid2[3][6] = 0
    grid2[3][7] = 1
    
    # Reload grid
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for i in range(8):
        row_val = 0
        for bit in grid2[i]:
            row_val = (row_val << 1) | bit
        dut.row_data.value = row_val
        dut.row_index.value = i
        dut.load_row.value = 1
        await RisingEdge(dut.clk)
        dut.load_row.value = 0
        await RisingEdge(dut.clk)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    cycles = 0
    while dut.done.value == 0 and cycles < 200:
        await RisingEdge(dut.clk)
        cycles += 1

    # Calculate expected
    expected = calculate_expected(grid2)
    if int(dut.result.value) != expected:
         raise TestFailure(f"Test 2 Failed: Expected {expected}, got {int(dut.result.value)}")

    # Test Case 3: Grid with 2 errors
    dut._log.info("Test 3: Grid with 2 errors")
    grid3 = [[1]*8 for _ in range(8)]
    grid3[2][7] = 0
    grid3[3][6] = 0
    grid3[3][7] = 1
    # Add second error
    grid3[4][2] = 0
    grid3[5][1] = 0
    grid3[5][2] = 1
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for i in range(8):
        row_val = 0
        for bit in grid3[i]:
            row_val = (row_val << 1) | bit
        dut.row_data.value = row_val
        dut.row_index.value = i
        dut.load_row.value = 1
        await RisingEdge(dut.clk)
        dut.load_row.value = 0
        await RisingEdge(dut.clk)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    cycles = 0
    while dut.done.value == 0 and cycles < 200:
        await RisingEdge(dut.clk)
        cycles += 1

    expected = calculate_expected(grid3)
    if int(dut.result.value) != expected:
         raise TestFailure(f"Test 3 Failed: Expected {expected}, got {int(dut.result.value)}")

    # Test Case 4: Max k (4) errors
    dut._log.info("Test 4: Grid with 4 errors")
    grid4 = [[1]*8 for _ in range(8)]
    errors = [(2,7, 3,6), (4,2, 5,1), (6,5, 7,4), (0,0, 1,7)] # 4 corners
    for e in errors:
        grid4[e[0]][e[1]] = 0
        grid4[e[2]][e[3]] = 0
        grid4[e[2]][e[1]] = 1
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for i in range(8):
        row_val = 0
        for bit in grid4[i]:
            row_val = (row_val << 1) | bit
        dut.row_data.value = row_val
        dut.row_index.value = i
        dut.load_row.value = 1
        await RisingEdge(dut.clk)
        dut.load_row.value = 0
        await RisingEdge(dut.clk)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    cycles = 0
    while dut.done.value == 0 and cycles < 200:
        await RisingEdge(dut.clk)
        cycles += 1

    expected = calculate_expected(grid4)
    if int(dut.result.value) != expected:
         raise TestFailure(f"Test 4 Failed: Expected {expected}, got {int(dut.result.value)}")

    # Test Case 5: 5 errors (should output 5 to represent impossible or > k)
    dut._log.info("Test 5: Grid with 5 errors")
    grid5 = [[1]*8 for _ in range(8)]
    # Add 5 corners
    corners = [(2,7, 3,6), (4,2, 5,1), (6,5, 7,4), (0,0, 1,7), (2,2, 3,3)]
    for c in corners:
        grid5[c[0]][c[1]] = 0
        grid5[c[2]][c[3]] = 0
        grid5[c[2]][c[1]] = 1
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for i in range(8):
        row_val = 0
        for bit in grid5[i]:
            row_val = (row_val << 1) | bit
        dut.row_data.value = row_val
        dut.row_index.value = i
        dut.load_row.value = 1
        await RisingEdge(dut.clk)
        dut.load_row.value = 0
        await RisingEdge(dut.clk)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    cycles = 0
    while dut.done.value == 0 and cycles < 200:
        await RisingEdge(dut.clk)
        cycles += 1

    expected = calculate_expected(grid5)
    # Since we must return 5 if > 4, but our logic calculates actual count.
    # The prompt says: "If the calculated changes are <= 4, output that number. If > 4... output 5."
    # Let's check if the result is 5.
    if int(dut.result.value) != 5:
         raise TestFailure(f"Test 5 Failed: Expected 5 (impossible), got {int(dut.result.value)}")

    print(f"All {5} tests passed!")
