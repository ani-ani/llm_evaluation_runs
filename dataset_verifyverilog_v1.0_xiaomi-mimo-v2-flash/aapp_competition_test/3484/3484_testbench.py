import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants for 8x8 Latin Square
N = 8
DATA_WIDTH = 4  # Values 1-8 fit in 4 bits
CLK_NS = 10
MAX_CYCLES = 10000

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'valid_input'):
        dut.valid_input.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def verify_solution(grid):
    # grid is 64 integers
    # Check rows
    for r in range(N):
        row_vals = set()
        for c in range(N):
            val = grid[r * N + c]
            if val < 1 or val > N:
                raise TestFailure(f"Value {val} out of range at ({r},{c})")
            row_vals.add(val)
        if len(row_vals) != N:
            raise TestFailure(f"Row {r} does not contain distinct values 1-{N}")
    
    # Check cols
    for c in range(N):
        col_vals = set()
        for r in range(N):
            val = grid[r * N + c]
            col_vals.add(val)
        if len(col_vals) != N:
            raise TestFailure(f"Column {c} does not contain distinct values 1-{N}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_superdoku_solver(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)

    # Test Case 1: Valid 8x8 Latin Square initial rows (first 2 rows)
    # Example: Cyclic shift rows
    # Row 0: 1 2 3 4 5 6 7 8
    # Row 1: 2 3 4 5 6 7 8 1
    initial_grid = [
        1, 2, 3, 4, 5, 6, 7, 8,
        2, 3, 4, 5, 6, 7, 8, 1
    ]
    k = 2
    
    dut._log.info(f"Starting test with k={k}, valid input")
    
    # Load inputs
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Input Phase (assuming sequential loading for simplicity based on spec)
    # The spec describes input_row, input_col, input_val
    for r in range(k):
        for c in range(N):
            dut.input_row.value = r
            dut.input_col.value = c
            dut.input_val.value = initial_grid[r * N + c]
            dut.valid_input.value = 1
            await RisingEdge(dut.clk)
    dut.valid_input.value = 0
    
    # Wait for solver
    await wait_for_done(dut)
    
    if not is_value_defined(dut.solvable.value):
        raise TestFailure("solvable signal undefined")
        
    solvable = int(dut.solvable.value)
    dut._log.info(f"Result: solvable={solvable}")
    
    if solvable != 1:
        raise TestFailure(f"Expected solvable=1 for valid input, got {solvable}")
        
    # Read result grid
    result_grid = []
    if hasattr(dut.result_grid, '__iter__'):
        # It's an array
        for i in range(N * N):
            val = int(dut.result_grid[i].value)
            result_grid.append(val)
    else:
        # It's a packed signal, we need to unpack
        # Or perhaps it's a bus of 64 signals? 
        # Assuming individual access via index for robustness
        # If the spec implies a packed signal, we calculate it
        try:
            packed_val = int(dut.result_grid.value)
            for i in range(N * N):
                val = (packed_val >> (i * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1)
                result_grid.append(val)
        except ValueError:
             raise TestFailure("Could not read result_grid")

    dut._log.info(f"Result grid: {result_grid}")
    
    # Verify correctness
    await verify_solution(result_grid)
    
    # Verify initial rows match
    for r in range(k):
        for c in range(N):
            if result_grid[r * N + c] != initial_grid[r * N + c]:
                raise TestFailure(f"Initial row {r} col {c} modified in result")

    # Test Case 2: Invalid input (duplicate in row)
    dut._log.info("Testing invalid case...")
    await reset_dut(dut)
    
    # Row 0: 1 2 3 4 5 6 7 8
    # Row 1: 2 2 4 5 6 7 8 1 (Duplicate 2)
    invalid_grid = [
        1, 2, 3, 4, 5, 6, 7, 8,
        2, 2, 4, 5, 6, 7, 8, 1
    ]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for r in range(k):
        for c in range(N):
            dut.input_row.value = r
            dut.input_col.value = c
            dut.input_val.value = invalid_grid[r * N + c]
            dut.valid_input.value = 1
            await RisingEdge(dut.clk)
    dut.valid_input.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.solvable.value):
        raise TestFailure("solvable signal undefined in invalid case")
        
    solvable = int(dut.solvable.value)
    dut._log.info(f"Invalid case result: solvable={solvable}")
    
    if solvable != 0:
        raise TestFailure(f"Expected solvable=0 for invalid input, got {solvable}")
