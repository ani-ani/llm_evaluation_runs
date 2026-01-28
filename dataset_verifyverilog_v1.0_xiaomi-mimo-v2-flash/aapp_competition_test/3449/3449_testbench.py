import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Scaled calculation for reference
def calculate_expected(B, H, grid, scale=1000, rows=8, cols=8):
    # Grid is 8x8, but we only care about internal cells (1 to 6)
    # B and H are integers
    dark_map = [[False] * cols for _ in range(rows)]
    
    # Calculate light levels for internal cells
    for r in range(1, rows - 1):
        for c in range(1, cols - 1):
            total_light = 0
            for r_l in range(rows):
                for c_l in range(cols):
                    s = grid[r_l][c_l]
                    if s == 0:
                        continue
                    dr = abs(r - r_l)
                    dc = abs(c - c_l)
                    dist_sq = dr*dr + dc*dc + H*H
                    # Integer contribution: (s * scale) / dist_sq
                    if dist_sq > 0:
                        total_light += int((s * scale) / dist_sq)
            
            if total_light < (B * scale):
                dark_map[r][c] = True
            else:
                dark_map[r][c] = False
    
    # Calculate fencing cost
    cost = 0
    # Horizontal edges
    for r in range(1, rows - 1):
        for c in range(1, cols - 2):
            if dark_map[r][c] or dark_map[r][c+1]:
                cost += 11
            else:
                cost += 43
    
    # Vertical edges
    for r in range(1, rows - 2):
        for c in range(1, cols - 1):
            if dark_map[r][c] or dark_map[r+1][c]:
                cost += 11
            else:
                cost += 43
                
    return cost

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_light_fence(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Helper to write 8x8 grid of 4-bit values
    async def write_grid(dut, grid_vals):
        # Assuming dut.grid is an array of 8 signals, each 4-bit
        for r in range(8):
            # Check if dut.grid[r] exists
            if has_signal(dut, f'grid_{r}'):
                cell_val = 0
                for c in range(8):
                    cell_val |= (grid_vals[r][c] & 0xF) << (c*4)
                getattr(dut, f'grid_{r}').value = cell_val
            # Or if dut.grid is a single signal per row
            elif has_signal(dut, 'grid') and hasattr(dut.grid, '__getitem__'):
                dut.grid[r].value = grid_vals[r][0] # Fallback
    
    # Test Case 1: From prompt
    B1, H1 = 9, 1
    grid1 = [
        [3,3,3,3,3,3,0,0],
        [3,0,0,0,0,3,0,0],
        [3,0,0,0,0,3,0,0],
        [3,0,0,0,0,3,0,0],
        [3,0,0,0,0,3,0,0],
        [3,3,3,3,3,3,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0]
    ]
    # The input specifies 6x6, so we pad to 8x8 as per spec constraints (borders sufficient)
    # Let's simulate the 6x6 logic in a 8x8 grid where borders (0 and 7) are 0 but 'sufficient'
    # Wait, the problem says borders are guaranteed sufficient, so we can treat edges as 'light'
    # but for calculation, we only calculate internal 1..R-2 or 1..C-2.
    # Let's adjust grid1 to be fully 8x8 compliant with the logic.
    # The 6x6 grid in input fits in 8x8 starting at (1,1).
    grid1 = [
        [0,0,0,0,0,0,0,0],
        [0,3,3,3,3,3,3,0],
        [0,3,0,0,0,0,3,0],
        [0,3,0,0,0,0,3,0],
        [0,3,0,0,0,0,3,0],
        [0,3,0,0,0,0,3,0],
        [0,3,3,3,3,3,3,0],
        [0,0,0,0,0,0,0,0]
    ]
    # Note: The problem guarantees borders are sufficient, so we assume cells (0,*) and (7,*) are sufficient.
    # However, we only fence internal edges. The calculation is for internal cells.
    # Let's run the calculation logic in Python to verify expected result for 6x6 grid logic (scaled to 8x8 logic)
    # The 6x6 grid in prompt maps to indices 1..6 in our 8x8 representation.
    expected1 = calculate_expected(B1, H1, grid1)
    
    # Write inputs
    dut.B.value = B1
    dut.H.value = H1
    
    # Write grid
    # Check if grid is a packed array per row (common in HDL) or flattened
    # Assuming 8 signals 'grid_0'...'grid_7' each 32-bit wide (8x4)
    for r in range(8):
        val = 0
        for c in range(8):
            val |= (grid1[r][c] & 0xF) << (c * 4)
        if has_signal(dut, f'grid_{r}'):
            getattr(dut, f'grid_{r}').value = val
        elif has_signal(dut, 'grid') and len(dut.grid) > r:
             dut.grid[r].value = val
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    if result != expected1:
        raise TestFailure(f"Test 1: Expected {expected1}, got {result}")
    
    cocotb.log.info(f"Test 1 passed: {result}")
    
    # Test Case 2
    B2, H2 = 5, 2
    grid2 = [
        [0,0,0,0,0,0,0,0],
        [0,6,3,2,3,2,2,6],
        [0,3,0,0,0,0,0,5],
        [0,2,0,0,0,0,0,2],
        [0,2,0,0,0,0,0,2],
        [0,5,0,0,0,0,0,3],
        [0,6,2,2,3,2,3,6],
        [0,0,0,0,0,0,0,0]
    ]
    expected2 = calculate_expected(B2, H2, grid2)
    
    dut.B.value = B2
    dut.H.value = H2
    
    for r in range(8):
        val = 0
        for c in range(8):
            val |= (grid2[r][c] & 0xF) << (c * 4)
        if has_signal(dut, f'grid_{r}'):
            getattr(dut, f'grid_{r}').value = val
        elif has_signal(dut, 'grid') and len(dut.grid) > r:
             dut.grid[r].value = val
             
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    if result != expected2:
        raise TestFailure(f"Test 2: Expected {expected2}, got {result}")
    
    cocotb.log.info(f"Test 2 passed: {result}")
