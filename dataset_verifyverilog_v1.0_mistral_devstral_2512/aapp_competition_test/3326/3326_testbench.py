import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 9  # 3x3 grid
COUNT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Monotonicity check for subgrid
def check_subgrid_monotonic(grid, row_mask, col_mask, r, c):
    """Check if subgrid defined by row_mask and col_mask is monotonic."""
    # Extract rows
    rows = []
    for i in range(r):
        if row_mask & (1 << i):
            row = []
            for j in range(c):
                if col_mask & (1 << j):
                    row.append(grid[i][j])
            rows.append(row)
    
    # Check rows
    for row in rows:
        if len(row) <= 1:
            continue
        # Check if increasing or decreasing
        is_inc = all(row[i] < row[i+1] for i in range(len(row)-1))
        is_dec = all(row[i] > row[i+1] for i in range(len(row)-1))
        if not (is_inc or is_dec):
            return False
    
    # Check columns
    cols = []
    for j in range(c):
        if col_mask & (1 << j):
            col = []
            for i in range(r):
                if row_mask & (1 << i):
                    col.append(grid[i][j])
            cols.append(col)
    
    for col in cols:
        if len(col) <= 1:
            continue
        is_inc = all(col[i] < col[i+1] for i in range(len(col)-1))
        is_dec = all(col[i] > col[i+1] for i in range(len(col)-1))
        if not (is_inc or is_dec):
            return False
    
    return True

async def write_grid(dut, grid):
    """Write 3x3 grid to DUT."""
    # Map to individual ports
    dut.grid_0_0.value = clamp_to_width(grid[0][0], DATA_WIDTH)
    dut.grid_0_1.value = clamp_to_width(grid[0][1], DATA_WIDTH)
    dut.grid_0_2.value = clamp_to_width(grid[0][2], DATA_WIDTH)
    dut.grid_1_0.value = clamp_to_width(grid[1][0], DATA_WIDTH)
    dut.grid_1_1.value = clamp_to_width(grid[1][1], DATA_WIDTH)
    dut.grid_1_2.value = clamp_to_width(grid[1][2], DATA_WIDTH)
    dut.grid_2_0.value = clamp_to_width(grid[2][0], DATA_WIDTH)
    dut.grid_2_1.value = clamp_to_width(grid[2][1], DATA_WIDTH)
    dut.grid_2_2.value = clamp_to_width(grid[2][2], DATA_WIDTH)

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Start computation."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_monotonic_subgrid(dut):
    """Test monotonic subgrid counting."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (grid, r, c, expected_count, description)
    test_cases = [
        # Example from problem: 3x3 grid
        ([
            [1, 2, 5],
            [7, 6, 4],
            [9, 8, 3]
        ], 3, 3, 49, "Original example 3x3"),
        
        # Simple monotonic 2x2
        ([
            [1, 2],
            [3, 4]
        ], 2, 2, 9, "Simple 2x2 increasing"),
        
        # 1x1 grid
        ([
            [1, 0, 0],
            [0, 0, 0],
            [0, 0, 0]
        ], 1, 1, 1, "Single 1x1 element"),
        
        # 2x2 decreasing
        ([
            [4, 3],
            [2, 1]
        ], 2, 2, 9, "2x2 decreasing"),
        
        # Non-monotonic in middle
        ([
            [1, 3, 2],
            [4, 5, 6],
            [7, 8, 9]
        ], 3, 3, 40, "Non-monotonic row 0"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (grid, r, c, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Write grid to DUT
            await write_grid(dut, grid)
            
            # Set r and c
            dut.r.value = r
            dut.c.value = c
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.count.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.count.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: count = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")