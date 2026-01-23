import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Compute expected grid function
def compute_expected(r, c, i, j, n):
    # i, j are 1-based, convert to 0-based
    i0 = i-1
    j0 = j-1
    # initialize grid with 0 ('.')
    grid = [[0 for _ in range(c)] for _ in range(r)]
    # Directions: up, right, down, left
    directions = [(-1, 0), (0, 1), (1, 0), (0, -1)]
    row, col = i0, j0
    direction = 0
    color = 0  # 0 for 'A', so when we store, we use color+1 for 'A'
    stepSize = 1

    # Color the start cell with initial color
    grid[row][col] = color + 1  # 'A'

    for _ in range(n):
        # move stepSize steps
        for _ in range(stepSize):
            # move one step
            dr, dc = directions[direction]
            row = (row + dr) % r
            col = (col + dc) % c
            # color the cell
            grid[row][col] = color + 1
        # rotate direction
        direction = (direction + 1) % 4
        # switch color
        color = (color + 1) % 26
        stepSize += 1

    # mark final position with '@' which is 27
    grid[row][col] = 27

    return grid

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_zamboni(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (i, j, n)
    test_cases = [
        (3, 3, 4),  # from sample, but on 8x8 grid
        (3, 3, 7),  # from sample, on 8x8 grid
    ]
    
    for test_case in test_cases:
        i_val, j_val, n_val = test_case
        cocotb.log.info(f"Testing i={i_val}, j={j_val}, n={n_val}")
        
        # Reset grid to white for all cells before each test
        for row in range(8):
            for col in range(8):
                dut.grid[row][col].value = 0
        
        # Set inputs
        dut.i.value = i_val
        dut.j.value = j_val
        dut.n.value = n_val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 1000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout: done not asserted after {timeout} cycles")
        
        # Compute expected grid
        expected_grid = compute_expected(8, 8, i_val, j_val, n_val)
        
        # Verify grid
        for row in range(8):
            for col in range(8):
                dut_val = int(dut.grid[row][col].value)
                expected_val = expected_grid[row][col]
                if dut_val != expected_val:
                    raise TestFailure(f"Cell ({row},{col}): expected {expected_val}, got {dut_val}")
        
        cocotb.log.info(f"Test passed for i={i_val}, j={j_val}, n={n_val}")
