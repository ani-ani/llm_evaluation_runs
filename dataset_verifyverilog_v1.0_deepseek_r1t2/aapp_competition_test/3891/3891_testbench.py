import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def write_packed_grid(dut, packed_value):
    """Write packed grid value to DUT."""
    dut.grid_packed.value = packed_value

async def read_result(dut):
    """Read row and column centers from DUT."""
    row = safe_int(dut.row_center.value)
    col = safe_int(dut.col_center.value)
    return row, col

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=200):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# TEST CASES
# ============================================================================

def create_packed_grid(n, m, lines, N=8, M=8):
    """
    Create a packed 8x8 grid from the given n x m grid.
    Place the input grid in the top-left corner; fill rest with white (0).
    Returns a 64-bit integer.
    """
    # Initialize 8x8 grid with zeros
    grid = [[0] * M for _ in range(N)]
    # Fill with given data
    for i in range(n):
        for j in range(m):
            if j < len(lines[i]) and lines[i][j] == 'B':
                grid[i][j] = 1
    # Pack into integer (row-major, bit 0 = (0,0))
    packed = 0
    for i in range(N):
        for j in range(M):
            if grid[i][j]:
                packed |= 1 << (i * M + j)
    return packed

# Define test cases: (description, n, m, lines, expected_row, expected_col)
TEST_CASES = [
    (
        "Example 1: 5x6 square",
        5, 6,
        [
            "WWBBBW",
            "WWBBBW",
            "WWBBBW",
            "WWWWWW",
            "WWWWWW"
        ],
        2, 4
    ),
    (
        "Example 2: single black",
        3, 3,
        [
            "WWW",
            "BWW",
            "WWW"
        ],
        2, 1
    ),
    (
        "Example 3: 5x5 square",
        5, 5,
        [
            "WWWWW",
            "WBBBW",
            "WBBBW",
            "WBBBW",
            "WWWWW"
        ],
        3, 3
    ),
    (
        "Example 4: 3x3 full black",
        3, 3,
        [
            "BBB",
            "BBB",
            "BBB"
        ],
        2, 2
    ),
    (
        "Single black cell",
        1, 1,
        [
            "B"
        ],
        1, 1
    ),
    (
        "Row only",
        1, 5,
        [
            "WWWWB"
        ],
        1, 5
    ),
    (
        "Column only",
        5, 1,
        [
            "W",
            "W",
            "B",
            "W",
            "W"
        ],
        3, 1
    ),
    (
        "3x3 with white border",
        3, 3,
        [
            "WWW",
            "WBW",
            "WWW"
        ],
        2, 2
    )
]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_black_square(dut):
    """Test the find_black_square module with multiple cases."""

    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)

    # Iterate over test cases
    for desc, n, m, lines, exp_row, exp_col in TEST_CASES:
        dut._log.info(f"Running test: {desc}")
        
        # Create packed grid
        packed = create_packed_grid(n, m, lines)
        
        # Write to DUT
        await write_packed_grid(dut, packed)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        row, col = await read_result(dut)
        
        # Verify
        if row != exp_row or col != exp_col:
            raise TestFailure(
                f"Test '{desc}' failed: expected ({exp_row}, {exp_col}), got ({row}, {col})"
            )
        
        dut._log.info(f"  PASS: ({row}, {col})")
        
        # Small delay before next test
        await Timer(100, units='ns')
    
    dut._log.info("All tests passed!")