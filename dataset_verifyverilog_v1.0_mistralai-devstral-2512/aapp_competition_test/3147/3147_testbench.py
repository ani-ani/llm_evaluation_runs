import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# --- Helpers (Section A) ---
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# --- Testbench Config ---
R_MAX, C_MAX = 16, 16
DATA_WIDTH, CLK_NS = 1, 10
MAX_CYCLES = 100000

# --- Helper: Rotate 180 logic in Python for verification ---
def is_rot180_symmetric(grid, r, c, size):
    for i in range(size):
        for j in range(size):
            val1 = grid[r + i][c + j]
            val2 = grid[r + size - 1 - i][c + size - 1 - j]
            if val1 != val2:
                return False
    return True

def find_max_size_python(grid, R, C):
    for s in range(min(R, C), 1, -1):
        for r in range(R - s + 1):
            for c in range(C - s + 1):
                if is_rot180_symmetric(grid, r, c, s):
                    return s
    return -1

# --- Helper: Pack matrix ---
def pack_matrix(grid, R, C):
    packed = 0
    for r in range(R):
        for c in range(C):
            if grid[r][c] == '1':
                packed |= (1 << (r * C + c))
    return packed

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_square_killer(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    else:
        raise TestFailure("Module requires a 'clk' signal")

    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
    else:
        # If no reset, ensure clean start
        for _ in range(2): await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)

    # --- Test Cases ---
    # Format: (R, C, Matrix Strings, Expected Size)
    test_cases = [
        (3, 6, 
         ["101010", "111001", "101001"], 
         3),
        (4, 5, 
         ["10010", "01010", "10101", "01001"], 
         3),
        (3, 3, 
         ["101", "111", "100"], 
         -1),
        (2, 2, 
         ["11", "11"], 
         2),
        (2, 2, 
         ["10", "01"], 
         2), # Rotated is same
        (1, 5, 
         ["10101"], 
         -1) # Size 1 is not allowed (>1)
    ]

    passed = 0
    failed = 0

    for idx, (R, C, matrix_strs, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {idx+1}: R={R}, C={C}, Expected={expected}")
        
        # Prepare Input
        grid = [list(row) for row in matrix_strs]
        packed_val = pack_matrix(grid, R, C)
        
        # Drive Inputs
        if has_signal(dut, 'matrix_in'):
            dut.matrix_in.value = packed_val
        else:
            # Check for individual row/col inputs if matrix_in is not found
            # This is a fallback, though 'matrix_in' is specified in prompt
            pass
            
        if has_signal(dut, 'R'):
            dut.R.value = R
        if has_signal(dut, 'C'):
            dut.C.value = C
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
             await RisingEdge(dut.clk)

        # Wait for Done
        found_done = False
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                found_done = True
                break
        
        if not found_done:
            cocotb.log.error(f"Test {idx+1} FAILED: Timeout waiting for done signal")
            failed += 1
            continue

        # Read Result
        if not has_signal(dut, 'result'):
            cocotb.log.error("Test FAILED: 'result' signal not found")
            failed += 1
            continue

        result = int(dut.result.value)
        
        # Python verification for logging
        python_res = find_max_size_python(grid, R, C)
        if python_res != expected:
            cocotb.log.warning(f"Internal Python check mismatch: {python_res} vs Expected {expected}. Check test case definition.")

        if result == expected:
            cocotb.log.info(f"Test {idx+1} PASSED: Result {result}")
            passed += 1
        else:
            cocotb.log.error(f"Test {idx+1} FAILED: Expected {expected}, got {result}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
