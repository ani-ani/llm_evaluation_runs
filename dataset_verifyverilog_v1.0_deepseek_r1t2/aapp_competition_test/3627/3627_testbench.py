import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import re

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_grid(dut, grid, max_rows, max_cols, cost_width):
    """Write grid values to the 2D array."""
    for r in range(max_rows):
        for c in range(max_cols):
            dut.grid[r][c].value = clamp_to_width(grid[r][c], cost_width)

async def read_result(dut):
    """Read result and done signals."""
    if is_value_defined(dut.result.value):
        return int(dut.result.value)
    else:
        raise TestFailure("Result is undefined (X/Z)")

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# INPUT PARSING
# ============================================================================

def parse_input(input_str):
    """Parse the input string and return R, C, grid, start_mask, end_mask."""
    lines = input_str.strip().split('\n')
    # First line: R C
    R, C = map(int, lines[0].split())
    # Second line: row of 'E'
    # Next R lines: costs
    cost_lines = lines[2:2+R]
    # Last line: row of 'S'
    
    # Build full grid: rows 0 to R+1
    MAX_ROWS = R + 2
    MAX_COLS = C
    grid = [[0 for _ in range(MAX_COLS)] for _ in range(MAX_ROWS)]
    
    # Row 0 is top (end), cost 0 (already set)
    # Rows 1 to R: costs
    for r in range(1, R+1):
        costs = list(map(int, cost_lines[r-1].split()))
        for c in range(C):
            grid[r][c] = costs[c]
    # Row R+1 is bottom (start), cost 0 (already set)
    
    return R, C, grid

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_min_energy(dut):
    """Test the min_energy module with sample inputs."""
    
    # Constants matching Verilog parameters
    MAX_ROWS = 17
    MAX_COLS = 15
    COST_WIDTH = 4
    DP_WIDTH = 12
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: input string, expected output
    test_cases = [
        (
            "5 5\nE E E E E\n1 2 3 4 5\n5 4 3 2 1\n-2 -2 -2 -2 -2\n8 8 8 8 8\n9 9 9 9 9\nS S S S S\n",
            17
        ),
        (
            "13 5\nE E E E E\n1 1 1 1 1\n1 1 1 2 1\n9 9 9 9 1\n1 1 1 9 1\n1 9 1 1 1\n1 9 9 9 9\n1 2 3 4 5\n2 3 4 5 6\n3 4 5 6 7\n4 5 6 7 8\n9 6 7 8 9\n-5 9 -7 9 -5\n6 0 7 0 5\nS S S S S\n",
            32
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected) in enumerate(test_cases):
        dut._log.info(f"Running test case {i+1}")
        
        # Parse input
        R, C, grid = parse_input(input_str)
        
        # Set R and C
        dut.R.value = R
        dut.C.value = C
        
        # Write grid to DUT
        for r in range(MAX_ROWS):
            for c in range(MAX_COLS):
                val = grid[r][c] if r < len(grid) and c < len(grid[0]) else 0
                # Clamp to 4-bit signed range (-8 to 7, but we use 4-bit unsigned for assignment)
                # The Verilog expects signed, but we assign as unsigned and it will interpret as signed
                dut.grid[r][c].value = clamp_to_width(val, COST_WIDTH)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut, max_cycles=50000)
        
        # Read result
        result = await read_result(dut)
        
        if result != expected:
            dut._log.error(f"Test {i+1} FAILED: expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"Test {i+1} PASSED: result = {result}")
            passed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")