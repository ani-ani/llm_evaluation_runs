import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants for the 8x8 grid
GRID_ROWS = 8
GRID_COLS = 8
DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 300

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Compute max perimeter for a given grid (Python reference)
def compute_max_perimeter(grid):
    R = GRID_ROWS
    C = GRID_COLS
    # Prefix sums
    pref = [[0] * (C + 1) for _ in range(R + 1)]
    for i in range(R):
        for j in range(C):
            pref[i+1][j+1] = pref[i][j+1] + pref[i+1][j] - pref[i][j] + grid[i][j]
    
    max_perim = 0
    for r1 in range(R):
        for c1 in range(C):
            for r2 in range(r1, R):
                for c2 in range(c1, C):
                    area = pref[r2+1][c2+1] - pref[r1][c2+1] - pref[r2+1][c1] + pref[r1][c1]
                    rect_area = (r2 - r1 + 1) * (c2 - c1 + 1)
                    if area == rect_area:
                        perim = 2 * ((r2 - r1 + 1) + (c2 - c1 + 1))
                        if perim > max_perim:
                            max_perim = perim
    return max_perim

def generate_test_cases():
    cases = []
    # Case 1: All free 2x2 -> 8x8 full free
    grid1 = [[1 for _ in range(GRID_COLS)] for _ in range(GRID_ROWS)]
    # Actually max perimeter for 8x8 is 2*(8+8)=32
    cases.append((grid1, 32, "All free 8x8"))
    
    # Case 2: Some blocked
    grid2 = [[1 for _ in range(GRID_COLS)] for _ in range(GRID_ROWS)]
    grid2[2][2] = 0
    grid2[2][3] = 0
    # Still mostly free, max perim likely 32
    cases.append((grid2, 32, "Mostly free with holes"))
    
    # Case 3: Checkerboard pattern (alternating X and .)
    grid3 = [[1 if (i + j) % 2 == 0 else 0 for j in range(GRID_COLS)] for i in range(GRID_ROWS)]
    # Max free rectangle is 1x1, perimeter 4
    cases.append((grid3, 4, "Checkerboard"))
    
    # Case 4: Large empty block (4x4)
    grid4 = [[0 for _ in range(GRID_COLS)] for _ in range(GRID_ROWS)]
    for i in range(2, 6):
        for j in range(2, 6):
            grid4[i][j] = 1
    # Max free is 4x4, perimeter 16
    cases.append((grid4, 16, "Central 4x4 block"))
    
    # Case 5: Sparse (2 free cells far apart) -> max perim 4
    grid5 = [[0 for _ in range(GRID_COLS)] for _ in range(GRID_ROWS)]
    grid5[0][0] = 1
    grid5[7][7] = 1
    cases.append((grid5, 4, "Two isolated cells"))
    
    # Case 6: Full X (all blocked) -> 0
    grid6 = [[0 for _ in range(GRID_COLS)] for _ in range(GRID_ROWS)]
    cases.append((grid6, 0, "All blocked"))
    
    # Case 7: Specific from sample (adapted to 8x8, copy top-left 4x4)
    # 4x4 sample: X.XX / X..X / ..X. / ..XX
    grid7 = [[0 for _ in range(GRID_COLS)] for _ in range(GRID_ROWS)]
    pattern = [
        [0,1,0,0],
        [0,1,1,0],
        [1,1,0,1],
        [1,1,0,0]
    ]
    for i in range(4):
        for j in range(4):
            grid7[i][j] = pattern[i][j]
    # Fill rest with 1
    for i in range(4, GRID_ROWS):
        for j in range(GRID_COLS):
            grid7[i][j] = 1
    for i in range(GRID_ROWS):
        for j in range(4, GRID_COLS):
            grid7[i][j] = 1
    # Free area is top-left 4x4 minus the X's, plus the rest. Largest rectangle likely 8x5 or 5x8.
    # Check: bottom-right 4x5 (rows 4-7, cols 3-7) is all 1s? Col 3 is all 1s in row 4-7.
    # Row 4-7 cols 3-7: 5x5 area all 1s? Grid7[4][3] is 1, yes. 5x5 perimeter 20.
    # Top-left has 2x3 free block? Row 0-1 cols 1-2? Grid[0][1]=1, [0][2]=0, so no.
    # Maybe 4x2? Row 1 cols 1-2? [1][1]=1, [1][2]=1, [1][3]=0, so 1x2.
    # Let's calculate precisely in Python.
    actual = compute_max_perimeter(grid7)
    cases.append((grid7, actual, "Adapted sample 2"))
    
    return cases

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_max_perimeter(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = generate_test_cases()
    passed = 0
    failed = 0
    
    for i, (grid, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write grid to DUT
            for r in range(GRID_ROWS):
                for c in range(GRID_COLS):
                    # Assuming flattened access or row-wise array of arrays
                    # If dut.grid_r_c exists
                    if has_signal(dut, f'grid_{r}_{c}'):
                        getattr(dut, f'grid_{r}_{c}').value = grid[r][c]
                    else:
                        # Fallback: assume grid is a 2D array in HDL, accessible as dut.grid[r]
                        dut.grid[r].value = 0  # Clear previous
                        # We need to pack bits if it's a bus
                        # Since spec says 8x8-bit array, let's assume dut.grid is 8 bits wide for each row
                        # dut.grid[r].value is 8 bits
                        row_val = 0
                        for c2 in range(GRID_COLS):
                            row_val |= (grid[r][c2] & 1) << c2
                        dut.grid[r].value = row_val
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed: raise TestFailure(f"{failed} tests failed")