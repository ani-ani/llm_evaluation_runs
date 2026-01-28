import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=2500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Python logic for verification
def python_logic(grid_flat_256):
    # Decode flat bitstring to 16x16 list
    grid = []
    for i in range(16):
        row = []
        for j in range(16):
            idx = i * 16 + j
            bit = (grid_flat_256 >> idx) & 1
            row.append(bit)
        grid.append(row)
    
    # Check Row Contiguity & Empty
    empty_rows = 0
    for i in range(16):
        blacks = [j for j in range(16) if grid[i][j] == 1]
        if not blacks:
            empty_rows += 1
            continue
        if blacks[-1] - blacks[0] + 1 != len(blacks):
            return -1
            
    # Check Col Contiguity & Empty
    empty_cols = 0
    for j in range(16):
        blacks = [i for i in range(16) if grid[i][j] == 1]
        if not blacks:
            empty_cols += 1
            continue
        if blacks[-1] - blacks[0] + 1 != len(blacks):
            return -1

    # Check Empty Logic Constraint
    if (empty_rows == 0 and empty_cols > 0) or (empty_cols == 0 and empty_rows > 0):
        return -1
    
    # Count Components (BFS)
    visited = [[False]*16 for _ in range(16)]
    components = 0
    from collections import deque
    
    for i in range(16):
        for j in range(16):
            if grid[i][j] == 1 and not visited[i][j]:
                components += 1
                q = deque([(i, j)])
                visited[i][j] = True
                while q:
                    r, c = q.popleft()
                    for dr, dc in [(-1,0), (1,0), (0,-1), (0,1)]:
                        nr, nc = r + dr, c + dc
                        if 0 <= nr < 16 and 0 <= nc < 16:
                            if grid[nr][nc] == 1 and not visited[nr][nc]:
                                visited[nr][nc] = True
                                q.append((nr, nc))
    return components

async def write_grid(dut, grid_flat_256):
    dut.grid_flat.value = grid_flat_256

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_magnets(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test Cases: (grid_flat_256, expected_result, description)
    # Grids are 16x16. We define 16x16 test cases here.
    
    # Case 1: Simple single component (3x3 top-left)
    # 16x16 grid, black at (0,0), (0,1), (1,0), (1,1)
    grid1 = 0
    for r in range(2):
        for c in range(2):
            grid1 |= (1 << (r * 16 + c))
    
    # Case 2: Two components separated by white
    # (0,0) and (0,3)
    grid2 = (1 << 0) | (1 << 3)
    
    # Case 3: Contiguity failure (Row) - 1,0 and 1,2 (gap at 1,1)
    # (Note: Row 1 has bits 0 and 2 set, skip 1. This is a gap.)
    grid3 = (1 << (1*16 + 0)) | (1 << (1*16 + 2))
    
    # Case 4: Empty row but not empty col -> Invalid (-1)
    # Black at (0,0). Row 1 empty. Col 0 has black. Col 1 empty. 
    # If Row 1 empty but Col 0 not empty, it's invalid per simplified logic.
    grid4 = (1 << 0)
    
    # Case 5: Contiguity failure (Col) - (0,0), (2,0)
    grid5 = (1 << 0) | (1 << (2*16))
    
    test_cases = [
        (grid1, 1, "Single 2x2 block"),
        (grid2, 2, "Two single dots"),
        (grid3, -1, "Row gap"),
        (grid4, -1, "Empty row vs non-empty col"),
        (grid5, -1, "Col gap")
    ]
    
    passed = 0
    failed = 0
    
    for i, (grid_flat, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            expected_py = python_logic(grid_flat)
            if expected != expected_py:
                cocotb.log.warning(f"Python logic mismatch: Expected {expected}, Py got {expected_py}. Using Py.")
                expected = expected_py

            await write_grid(dut, grid_flat)
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
            
            # Handle -1 mapping (usually 255 or max width)
            if expected == -1:
                # If width is 8 bits, -1 is usually 255
                # Check if result matches 255 (or whatever -1 maps to)
                if result != 255: 
                     # Sometimes HDL might output 0 for error if not implemented, check exact spec
                     # Spec says 255 for -1
                     raise TestFailure(f"Expected -1 (mapped to 255), got {result}")
            else:
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
