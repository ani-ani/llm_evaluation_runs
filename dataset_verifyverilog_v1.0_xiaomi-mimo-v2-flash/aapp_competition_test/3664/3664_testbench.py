import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# --- Helpers ---
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

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

# --- Main Test ---
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pacman_zamboni(dut):
    # Constants for the scaled problem
    GRID_ROWS = 5
    GRID_COLS = 5
    MAX_STEPS = 4
    CLK_NS = 10

    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper to wait for done
    async def wait_for_done():
        for _ in range(200):  # Generous timeout for 5x5 * 4 steps
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return
        raise TestFailure("Timeout waiting for 'done' signal")

    # Test Cases (Scaled to 5x5 and 4 steps based on prompt)
    # Input: r c i j n
    # Python Output: Expected grid (5x5 strings)
    test_cases = [
        {
            "in": (5, 5, 3, 3, 4),
            "out": [
                ".....",
                "..BBC",
                "..A.C",
                "....C",
                "@DDDD"
            ]
        },
        {
            "in": (5, 5, 3, 3, 7), # Note: prompt says max 4 steps, but 7 is in example. We cap at 4 steps.
             # Corrected expected output for 4 steps instead of 7:
             # 1. Step 1 (A, size 1): Up 1 -> (2,3). Paint A.
             # 2. Rot Right. Step 2 (B, size 2): Right 2 -> (2,0) (wraps). Paint B, B.
             # 3. Rot Down. Step 3 (C, size 3): Down 3 -> (0,0) (wraps). Paint C, C, C.
             # 4. Rot Left. Step 4 (D, size 4): Left 4 -> (0,1) (wraps). Paint D, D, D, D.
             # Final pos (0,1) -> @
            "out": [
                "@CDDB",
                "...CB",
                ".A.B.",
                ".....",
                "....."
            ]
        }
    ]

    for idx, tc in enumerate(test_cases):
        r, c, start_r, start_j, n = tc["in"]
        expected_grid = tc["out"]
        
        dut._log.info(f"Running Test Case {idx+1}: Start ({start_r},{start_j}) Steps {n}")
        
        # Map 1-based input to 0-based logic if needed. 
        # Prompt says row 1 is top. Verilog usually 0-based.
        # Let's use 0-based for Verilog: input-1.
        dut.row_start.value = start_r - 1
        dut.col_start.value = start_j - 1
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done()
        
        # Read out the grid
        # The module should output grid_data and grid_addr. 
        # We need to catch the valid data stream.
        
        actual_grid = [['.' for _ in range(GRID_COLS)] for _ in range(GRID_ROWS)]
        data_collected = False
        
        # Wait for grid_valid to go high (or monitor for a few cycles)
        for _ in range(200):
            await RisingEdge(dut.clk)
            if has_signal(dut, 'grid_valid') and safe_int(dut.grid_valid.value) == 1:
                addr = safe_int(dut.grid_addr.value)
                val = safe_int(dut.grid_data.value)
                
                # Convert ASCII to char
                if 32 <= val <= 126:
                    char = chr(val)
                else:
                    char = '?'
                    
                row = addr // GRID_COLS
                col = addr % GRID_COLS
                
                if 0 <= row < GRID_ROWS and 0 <= col < GRID_COLS:
                    actual_grid[row][col] = char
                    data_collected = True
        
        if not data_collected:
             raise TestFailure(f"Test {idx+1}: No valid grid data captured")
            
        # Compare
        for r_idx in range(GRID_ROWS):
            actual_row = "".join(actual_grid[r_idx])
            expected_row = expected_grid[r_idx]
            if actual_row != expected_row:
                dut._log.error(f"Row mismatch: Got '{actual_row}', Exp '{expected_row}'")
                raise TestFailure(f"Test {idx+1} Failed on row {r_idx+1}")
        
        dut._log.info(f"Test {idx+1} Passed")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)