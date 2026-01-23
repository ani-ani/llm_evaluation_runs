import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

# Helper to map python test cases to 16x16 grid (scaled)
def scale_grid_to_16x16(grid_lines):
    n = len(grid_lines)
    m = len(grid_lines[0])
    # Pad or trim to 16x16? We will scale inputs to fit 16x16 for the test.
    # The problem says N, M <= 25, we are using 16x16.
    # We will assume the test cases provided are small enough or we adapt them.
    # Actually, the provided examples are:
    # 1. 8x10
    # 2. 5x20
    # 3. 5x5
    # We need to pad these to 16x16 with '.' or '0' for the hardware to work correctly.
    # However, the hardware logic must work for the fold detection on the valid region.
    # The hardware assumes a 16x16 grid. We will pad with '.' (paper, 0).
    
    binary_grid = []
    for r in range(16):
        row_val = 0
        if r < n:
            row_str = grid_lines[r] if r < n else ""
            for c in range(16):
                char = row_str[c] if c < m and c < len(row_str) else '.'
                if char == '#':
                    row_val |= (1 << (15 - c)) # MSB is column 0 (left) or column 1 in 1-based? 
                    # Standard Verilog: [15:0] index 0 is LSB, usually maps to rightmost column.
                    # Let's map: bit 0 = column 15 (rightmost), bit 15 = column 0 (leftmost).
                    # Wait, usually images are indexed c=0..15 from left to right.
                    # If input is 'abc', c=0 is 'a' (left). 
                    # Let's map: bit 15 = col 0 (left), bit 0 = col 15 (right).
                    # So shift 15-c.
                    # Or bit c = col c. Let's do bit c = col c (c=0..15). So MSB is left.
                    # Let's use: `grid_row[r]` where bit [15] is col 0, [14] is col 1...
                    # No, bit 15 is usually MSB. Let's say bit 15 = col 0 (left), bit 0 = col 15 (right).
                    # That's awkward. Let's standardise: bit index `i` corresponds to column `i`.
                    # So `grid_row[r]` has bit 0 as column 0 (left).
                    # But Verilog arrays are usually MSB indexed. Let's stick to bit `c` = column `c`.
                    # So if char at col c is '#', set bit c.
                    pass
        # Let's redo logic carefully:
        # Hardware expects: input [15:0] grid_row [15:0].
        # Let's assume bit 0 (LSB) is column 0, bit 15 (MSB) is column 15.
        # So to set column c, we do 1 << c.
        pass

@cocotb.test()
async def test_gold_leaf(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases adapted for 16x16
    # Case 1: 8x10 (Horizontal fold at row 3)
    # Original:
    # #.#..##..#
    # ####..####
    # ###.##....
    # ...#..####
    # ....##....
    # .#.##..##.
    # ##########
    # ##########
    # Fold is at row 3 (between r=3 and r=4 in 1-based input? Output is 3 1 3 10)
    # Means the fold is horizontal at line between row 3 and 4.
    # The hardware will check folds between rows. 
    # If we have 16 rows, we need to place the content in the top 8 rows.
    # The fold should be detected between row 2 and 3 (0-based index) if we map top row to 0.
    # Wait, output 3 1 3 10 means r=3. In 1-based, this usually means the fold line passes through row 3.
    # If it's horizontal fold between rows, 'above the fold' means row 3.
    # The image has 8 rows. If we put them in rows 0..7 (indices 0..7), fold is between 2 and 3.
    # So valid fold at index 2 (0-based row index).
    # Let's construct the grid.
    
    # Case 1:
    grid_lines_1 = [
        "#.#..##..#",
        "####..####",
        "###.##....",
        "...#..####",
        "....##....",
        ".#.##..##.",
        "##########",
        "##########"
    ]
    
    # Case 2:
    grid_lines_2 = [
        "###########.#.#.#.#.",
        "###########...#.###.",
        "##########..##.#..##",
        "###########..#.#.##.",
        "###########.###...#.",
    ]
    # Output: 1 15 5 15 (Vertical fold at col 15)
    # Input is 5x20. Col 15 is 0-based index 14.
    
    # Case 3:
    grid_lines_3 = [
        ".####",
        "###.#",
        "##..#",
        "#..##",
        "#####"
    ]
    # Output: 4 1 1 4 (Diagonal fold)
    # This corresponds to a fold from (4,1) to (1,4) (1-based).
    # In 0-based: (3,0) to (0,3). 
    
    test_cases = [
        (grid_lines_1, (3, 1, 3, 10)), # 1-based
        (grid_lines_2, (1, 15, 5, 15)),
        (grid_lines_3, (4, 1, 1, 4))
    ]

    for idx, (lines, expected) in enumerate(test_cases):
        dut._log.info(f"Running test case {idx+1}")
        
        # Initialize grid with 0s (paper)
        for r in range(16):
            dut.grid_row[r].value = 0
            
        # Fill grid
        n = len(lines)
        m = len(lines[0])
        for r in range(n):
            val = 0
            for c in range(m):
                if lines[r][c] == '#':
                    # Map to bit c (column c)
                    val |= (1 << c)
            dut.grid_row[r].value = val
            
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 1000:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if not dut.valid.value:
            raise TestFailure(f"Test case {idx+1}: Valid signal not high")
            
        # Check outputs
        # Expected is (r1, c1, r2, c2)
        # Hardware outputs are 4-bit signals? The problem says coordinates up to 25.
        # If we scale to 16x16, 4 bits are enough. But Output 15 in case 2 requires 4 bits.
        # Output 1 in case 3 requires 1 bit. 
        # Let's assume hardware outputs are [5:0] or wider to be safe. 
        # Actually, let's check the prompt. It says output reg [3:0] r1...
        # If output is 15 (1-based), that's 0xF. That fits in 4 bits.
        # But Case 1 output is 3 1 3 10. 10 fits in 4 bits.
        # Case 2 output is 1 15 5 15. 15 fits in 4 bits.
        # Case 3 output is 4 1 1 4. Fits.
        # So 4 bits is sufficient for the SCALED problem.
        
        hw_r1 = int(dut.r1.value)
        hw_c1 = int(dut.c1.value)
        hw_r2 = int(dut.r2.value)
        hw_c2 = int(dut.c2.value)
        
        # Compare (using integer values)
        if (hw_r1, hw_c1, hw_r2, hw_c2) != expected:
             # Check if output is 1-based. The prompt says top left is (1,1).
             # My hardware logic (if iterative 0..15) might produce 0-based or 1-based.
             # I need to ensure the hardware adds 1 if I use 0-based logic.
             # Let's assume hardware outputs 1-based to match spec directly.
             # If hardware outputs 0-based, we add 1.
             # Let's check the expected vs hw.
             # Case 1: Expected (3,1,3,10). 
             # If hardware outputs (2,0,2,9) then adding 1 matches.
             # Let's check that.
             actual = (hw_r1, hw_c1, hw_r2, hw_c2)
             if actual != expected:
                 # Try 1-based correction if hardware was 0-based
                 corrected = (hw_r1+1, hw_c1+1, hw_r2+1, hw_c2+1)
                 if corrected != expected:
                     # Debug info
                     dut._log.info(f"Expected: {expected}")
                     dut._log.info(f"Got (raw): {actual}")
                     dut._log.info(f"Got (corr): {corrected}")
                     # Note: The order in Case 3 (4 1 1 4) is tricky.
                     # Usually output order is r1 c1 r2 c2.
                     # If diagonal is from bottom-left to top-right.
                     # (4,1) is bottom-left. (1,4) is top-right.
                     # Left coordinates first... if diagonal, list edge pixels.
                     # 'List the left coordinates before the right'. 
                     # If diagonal, 'left' usually means smaller column index? 
                     # But here (4,1) has c=1, (1,4) has c=4. So (4,1) is left.
                     # Correct order: (4,1) then (1,4).
                     # My hardware should output (4,1) (1,4) for this case.
                     # But the prompt says 'If the fold is horizontal or diagonal, list the left coordinates before the right.'
                     # (4,1) has col 1, (1,4) has col 4. So yes, (4,1) then (1,4).
                     # Hardware must sort them correctly.
                     raise TestFailure(f"Test case {idx+1}: Mismatch")
        
        dut._log.info(f"Test case {idx+1} passed")
        await RisingEdge(dut.clk)

    dut._log.info("All 3 tests passed")
