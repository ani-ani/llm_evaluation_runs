import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def calculate_center(grid_input):
    # grid_input is list of strings like 'WWBBWW'
    # Returns (row, col) 1-based
    rows = len(grid_input)
    cols = len(grid_input[0]) if rows > 0 else 0
    
    r_min, r_max = rows, -1
    c_min, c_max = cols, -1
    
    found_any = False
    
    for r in range(rows):
        row_str = grid_input[r]
        if 'B' in row_str:
            if not found_any:
                found_any = True
            
            if r < r_min: r_min = r
            if r > r_max: r_max = r
            
            for c in range(cols):
                if row_str[c] == 'B':
                    if c < c_min: c_min = c
                    if c > c_max: c_max = c
    
    if not found_any:
        return (1, 1) # Fallback
        
    center_r = (r_min + r_max) // 2 + 1
    center_c = (c_min + c_max) // 2 + 1
    return (center_r, center_c)

async def write_grid(dut, grid_rows):
    # grid_rows is list of strings
    # We need to pack the string into an 8-bit integer for Verilog
    # 'W' -> 0, 'B' -> 1
    # Verilog module expects integer inputs grid_0...grid_15
    num_rows = len(grid_rows)
    dut.valid_rows.value = num_rows
    
    for r_idx, row_str in enumerate(grid_rows):
        val = 0
        for c_idx, char in enumerate(row_str):
            if char == 'B':
                val |= (1 << c_idx) # Set bit at column index
        
        # Assign to the specific port grid_0, grid_1, etc.
        port_name = f'grid_{r_idx}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = val
        else:
            raise TestFailure(f"Port {port_name} not found in DUT")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_square_center(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test Cases
    # 1. Example 1: 5x6
    grid1 = [
        "WWBBBW",
        "WWBBBW",
        "WWBBBW",
        "WWWWWW",
        "WWWWWW"
    ]
    
    # 2. Example 2: 3x3
    grid2 = [
        "WWW",
        "BWW",
        "WWW"
    ]
    
    # 3. Single B
    grid3 = ["B"]
    
    # 4. Full B block 3x3
    grid4 = [
        "BBB",
        "BBB",
        "BBB"
    ]
    
    # 5. Large 1x89
    grid5_row = "W"*44 + "B" + "W"*44
    grid5 = [grid5_row]
    
    # 6. Large 96x1
    # We can't actually drive 96 rows in this testbench since HDL is capped at 16.
    # But we will test a valid 16x1 case.
    grid6 = ["W"]*15 + ["B"] # B at row 15 (0-indexed)
    
    test_cases = [
        (grid1, (2, 4), "Example 1"),
        (grid2, (2, 1), "Example 2"),
        (grid3, (1, 1), "Single B"),
        (grid4, (2, 2), "3x3 Full B"),
        (grid5, (1, 45), "1x89 Single B"),
        (grid6, (8, 1), "16x1 Vertical") # 15 is index 15. (0+15)/2+1 = 8
    ]
    
    for i, (grid, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: {desc}")
        
        # Write grid
        await write_grid(dut, grid)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.center_row.value) or not is_value_defined(dut.center_col.value):
            raise TestFailure(f"Output undefined for test {desc}")
            
        r_out = int(dut.center_row.value)
        c_out = int(dut.center_col.value)
        
        exp_r, exp_c = expected
        
        if r_out != exp_r or c_out != exp_c:
            raise TestFailure(f"Test {desc} Failed: Expected ({exp_r}, {exp_c}), Got ({r_out}, {c_out})")
        
        # Reset before next test
        await reset_dut(dut)
