import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_monopole_magnet_solver(dut):
    """Test the Monopole Magnet Solver module."""
    
    # Create a clock with a 10ns period
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.grid_flat.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper task to load grid and run test
    async def run_test(grid_data, expected_result):
        # grid_data is a list of 16 bits (0 or 1) representing 4x4 grid
        flat_val = 0
        for i, bit in enumerate(grid_data):
            if bit:
                flat_val |= (1 << i)
        
        dut.grid_flat.value = flat_val
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 0
        while not dut.done.value and timeout < 200:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 200:
            raise TestFailure("Timeout waiting for done signal")
            
        # Check result
        actual = int(dut.result.value)
        
        # Handle expected -1 case (mapped to 15 in 4-bit unsigned)
        if expected_result == -1:
            if actual != 15:
                raise TestFailure(f"Test failed: Expected -1 (mapped to 15), got {actual}")
        else:
            if actual != expected_result:
                raise TestFailure(f"Test failed: Expected {expected_result}, got {actual}")
        
        print(f"Test passed: Input grid result is {actual}")

    # Test Case 1: Example 1 from prompt
    # Grid:
    # .#.
    # ###
    # ##.
    # Flattened (row major): 0,1,0, 1,1,1, 1,1,0, 0,0,0 (padded to 16 bits with 0s)
    # Let's create a 4x4 grid for our 4x4 limit. The prompt example is 3x3.
    # Let's map it to 4x4 by padding white.
    # Row 0: .#.. -> 0,1,0,0
    # Row 1: ###. -> 1,1,1,0
    # Row 2: ##.. -> 1,1,0,0
    # Row 3: .... -> 0,0,0,0
    grid1 = [
        0,1,0,0,
        1,1,1,0,
        1,1,0,0,
        0,0,0,0
    ]
    # Connected components: One component (top-right L-shape).
    # Contiguous rows/cols: Yes.
    # Empty rows/cols: Row 3 empty. Col 3: 0,0,0,0 -> empty. Consistent.
    await run_test(grid1, 1)

    # Test Case 2: Example 2 from prompt (adapted to 4x4)
    # Original 4x2:
    # ##
    # .#
    # .#
    # ##
    # In 4x4:
    # ##..
    # .#..
    # .#..
    # ##..
    # Col 0: 1,0,0,1. Pattern: 1, 0, 0, 1. Gap in middle -> Invalid (but contiguous check looks for gaps)
    # Let's use the provided failure condition: empty row/col mismatch or pattern.
    # Here, no empty row. No empty col. 
    # Row 1: .#. -> Gap? No, contiguous black cells are single. Wait, rules say: "If row has black, must be contiguous".
    # Row 1 has one black, so it's contiguous. Row 2 same.
    # Row 0: ## contiguous. Row 3: ## contiguous.
    # Cols: Col 0: 1,0,0,1. This IS a gap. The black cells are NOT contiguous in the column.
    # So this should be invalid.
    grid2 = [
        1,1,0,0,
        0,1,0,0,
        0,1,0,0,
        1,1,0,0
    ]
    await run_test(grid2, -1)

    # Test Case 3: Example 5 from prompt (all dots)
    # All white.
    grid3 = [0]*16
    await run_test(grid3, 0)

    # Test Case 4: Disconnected components
    # ..#.
    # ....
    # ..#.
    # ....
    # Two isolated black cells.
    grid4 = [
        0,0,1,0,
        0,0,0,0,
        0,0,1,0,
        0,0,0,0
    ]
    # Should be valid, result 2.
    # Row 0: single black (contiguous). Row 2: single black (contiguous).
    # Col 2: 1,0,1,0 -> Gap. INVALID.
    # Let's adjust to be valid.
    # Col 0: 1,0,1,0 -> Gap.
    # We need to avoid gaps in cols/rows if we want it valid.
    # Let's make two separate blocks in different rows/cols but ensure no internal gaps.
    # Block 1 at (0,0), Block 2 at (2,2).
    # Row 0: # -> ok. Row 2: ..# -> ok.
    # Col 0: # -> ok. Col 2: ..# -> ok.
    # Wait, the rule is "If a row has black, they must be contiguous". 
    # It does NOT say "If a row has black, it must touch other rows".
    # So two isolated cells are fine IF they don't form a gap in their respective rows/cols.
    # But wait, if we have # at (0,0) and # at (2,0), that's a gap in Col 0. Invalid.
    # So let's put them in different columns too.
    # (0,0) and (0,1) -> Row 0 is contiguous. 
    # (2,2) and (2,3) -> Row 2 is contiguous.
    # Col 0: 1,0,0,0 -> ok. Col 1: 1,0,0,0 -> ok.
    # Col 2: 0,0,1,0 -> ok. Col 3: 0,0,1,0 -> ok.
    grid4_valid = [
        1,1,0,0,
        0,0,0,0,
        0,0,1,1,
        0,0,0,0
    ]
    # Expected result: 2 (two components). 
    # Wait, check empty row/col consistency. Row 1 and 3 empty. Col 0-3 have black? No.
    # Col 0 has black. Col 1 has black. Col 2 has black. Col 3 has black.
    # So no empty columns. But we have empty rows. 
    # Rule: "(empty_row_flag != empty_col_flag)" -> -1.
    # So if we have empty rows, we MUST have empty cols.
    # Let's add an empty column to make it valid.
    # Col 4 (index 3) is empty in grid4_valid? No, row 2 has black in col 3.
    # Let's make Col 3 empty. Move block 2 to col 2.
    grid4_valid = [
        1,1,0,0,
        0,0,0,0,
        0,0,1,0,
        0,0,0,0
    ]
    # Now: Empty rows: 1, 3. Empty cols: 1 (if any?). 
    # Col 0: 1. Col 1: 0. Col 2: 1. Col 3: 0.
    # Empty cols: 1, 3. Empty rows: 1, 3. Consistent.
    # Contiguous check: Row 0: 1,1 -> ok. Row 2: 1 -> ok.
    # Cols: Col 0: 1 -> ok. Col 2: 1 -> ok.
    await run_test(grid4_valid, 2)

    # Test Case 5: Invalid pattern in row (gap)
    # #.#.
    grid5 = [
        1,0,1,0,
        0,0,0,0,
        0,0,0,0,
        0,0,0,0
    ]
    await run_test(grid5, -1)

    print("All tests completed successfully")
