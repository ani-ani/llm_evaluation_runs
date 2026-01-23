import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

# Mapping for ASCII to internal representation
# '.' -> 0, '#' -> 1, 'A'->65

def ascii_to_int(c):
    if c == '.': return 0
    if c == '#': return 1
    return ord(c)

def int_to_ascii(i):
    if i == 0: return '.'
    if i == 1: return '#'
    return chr(i)

@cocotb.test()
async def test_crossword_basic(dut):
    """Test the first example: 1x15 grid with 1 word"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')

    # Input 1: 1 15
    # Grid: ##.........#### (15 chars)
    # We map this to 8x8, filling row 0
    # Col 0-1: #, Col 2-10: ., Col 11-14: #
    # Max grid size 8, so we use 8x8 array
    grid_in = [[0]*8 for _ in range(8)]
    # Row 0
    grid_in[0][0] = 1
    grid_in[0][1] = 1
    for i in range(2, 11):
        grid_in[0][i] = 0
    grid_in[0][11] = 1
    grid_in[0][12] = 1
    grid_in[0][13] = 1
    grid_in[0][14] = 1
    # Note: indices > 14 unused in logic ideally, but we fill array

    for r in range(8):
        for c in range(8):
            dut.grid_in[r][c].value = grid_in[r][c]

    # Word list: 1 word "CROSSWORD"
    word_list = [[0]*8 for _ in range(16)]
    word = "CROSSWORD"
    for i, char in enumerate(word):
        word_list[0][i] = ord(char)
    
    for w in range(16):
        for c in range(8):
            dut.word_list[w][c].value = word_list[w][c]

    dut.num_words.value = 1
    dut.grid_width.value = 15 # Actual width of row 0
    dut.grid_height.value = 1

    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1

    if timeout >= 1000:
        raise TestFailure("Timed out waiting for done")

    # Check output
    # Expected: ##CROSSWORD#### (15 chars)
    # Mapped to 8x8: Row 0, Cols 0-14
    # 0,1: #. 2-10: C-R-O-S-S-W-O-R-D. 11-14: #
    
    dut._log.info("Output grid:")
    result_str = ""
    for r in range(8):
        row_str = ""
        for c in range(8):
            val = int(dut.grid_out[r][c].value)
            if r == 0 and c < 15:
                pass
            else:
                continue
            row_str += int_to_ascii(val)
        if row_str:
            dut._log.info(f"Row {r}: {row_str}")
            result_str += row_str
    
    # Verify
    expected = "##CROSSWORD####"
    if result_str != expected:
        raise TestFailure(f"Mismatch. Expected '{expected}', got '{result_str}'")

@cocotb.test()
async def test_crossword_complex(dut):
    """Test the second example: 3x6 grid with 6 words"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')

    # Input 2:
    # 3 6
    # #.....
    # ....##
    # ###...
    # Words: 6 (AT, ME, DOG, GOD, VETO, MAGIC)
    # Output:
    # #MAGIC
    # VETO##
    # ###DOG

    # Map to 8x8
    grid_in = [[0]*8 for _ in range(8)]
    # Row 0: #..... -> 1, 0, 0, 0, 0, 0
    grid_in[0][0] = 1
    grid_in[0][1] = 0
    grid_in[0][2] = 0
    grid_in[0][3] = 0
    grid_in[0][4] = 0
    grid_in[0][5] = 0
    # Row 1: ....## -> 0, 0, 0, 0, 1, 1
    grid_in[1][0] = 0
    grid_in[1][1] = 0
    grid_in[1][2] = 0
    grid_in[1][3] = 0
    grid_in[1][4] = 1
    grid_in[1][5] = 1
    # Row 2: ###... -> 1, 1, 1, 0, 0, 0
    grid_in[2][0] = 1
    grid_in[2][1] = 1
    grid_in[2][2] = 1
    grid_in[2][3] = 0
    grid_in[2][4] = 0
    grid_in[2][5] = 0

    for r in range(8):
        for c in range(8):
            dut.grid_in[r][c].value = grid_in[r][c]

    # Words
    words = ["AT", "ME", "DOG", "GOD", "VETO", "MAGIC"]
    word_list = [[0]*8 for _ in range(16)]
    for i, w in enumerate(words):
        for j, char in enumerate(w):
            word_list[i][j] = ord(char)
    
    for w in range(16):
        for c in range(8):
            dut.word_list[w][c].value = word_list[w][c]

    dut.num_words.value = 6
    dut.grid_width.value = 6
    dut.grid_height.value = 3

    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1

    if timeout >= 5000:
        raise TestFailure("Timed out waiting for done")

    # Verify
    # Expected rows:
    # 0: #MAGIC -> 1, 77, 65, 71, 73, 67
    # 1: VETO## -> 86, 69, 84, 79, 35, 35
    # 2: ###DOG -> 35, 35, 35, 68, 79, 71
    
    expected_grid = [
        [1, 77, 65, 71, 73, 67, 0, 0],
        [86, 69, 84, 79, 35, 35, 0, 0],
        [35, 35, 35, 68, 79, 71, 0, 0]
    ]

    error_count = 0
    for r in range(3):
        for c in range(6):
            got = int(dut.grid_out[r][c].value)
            exp = expected_grid[r][c]
            if got != exp:
                dut._log.error(f"Mismatch at ({r},{c}): Expected {exp} ({int_to_ascii(exp)}), Got {got} ({int_to_ascii(got)})")
                error_count += 1

    if error_count > 0:
        raise TestFailure(f"Grid mismatch: {error_count} errors found.")

    dut._log.info("All tests passed!")
