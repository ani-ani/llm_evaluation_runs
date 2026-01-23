import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 2      # 2 bits per color
GRID_SIZE = 8       # 8x8 grid
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Color encoding
COLOR_W = 0
COLOR_R = 1
COLOR_G = 2
COLOR_B = 3

# ============================================================================
# HELPER FUNCTIONS
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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_grid(dut, grid):
    """Write 8x8 grid to DUT."""
    for i in range(GRID_SIZE):
        for j in range(GRID_SIZE):
            # Access grid as 2D array: grid[i][j]
            # Try accessing as 2D array first
            try:
                cell_value = grid[i][j]
                dut.grid[i][j].value = clamp_to_width(cell_value, DATA_WIDTH)
            except (TypeError, AttributeError):
                # If grid is not 2D, handle differently
                raise TestFailure("Grid must be 2D array of size 8x8")

async def read_board(dut):
    """Read current board state from DUT."""
    board = []
    for i in range(GRID_SIZE):
        row = []
        for j in range(GRID_SIZE):
            if is_value_defined(dut.grid[i][j].value):
                row.append(int(dut.grid[i][j].value))
            else:
                row.append(None)
        board.append(row)
    return board

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TEST CASES
# ============================================================================

# Helper to create grid from string list
def create_grid_from_strings(strings):
    """Convert list of strings to 8x8 color grid."""
    grid = [[COLOR_W for _ in range(8)] for _ in range(8)]
    for i, line in enumerate(strings):
        for j, char in enumerate(line):
            if char == 'R':
                grid[i][j] = COLOR_R
            elif char == 'G':
                grid[i][j] = COLOR_G
            elif char == 'B':
                grid[i][j] = COLOR_B
            # 'W' stays as 0
    return grid

# Test case 1: Simple 3x3 block
test_case_1 = (
    create_grid_from_strings([
        "RRRWWWW",
        "RRRWWWW",
        "RRRWWWW",
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWWW"
    ]),
    1,  # Expected: YES
    "Simple 3x3 red block"
)

# Test case 2: Impossible pattern (like Sample 2)
test_case_2 = (
    create_grid_from_strings([
        "RRRWWRW",
        "RRRRWWW",
        "RRRRWWW",
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWWW"
    ]),
    0,  # Expected: NO
    "Impossible pattern - corner cells"
)

# Test case 3: All white
test_case_3 = (
    create_grid_from_strings([
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWWW"
    ]),
    1,  # Expected: YES
    "All white - trivial"
)

# Test case 4: Overlapping blocks (YES)
test_case_4 = (
    create_grid_from_strings([
        "RRRRRRR",
        "RRRRRRR",
        "RRRRRRR",
        "RRRRRRR",
        "RRRRRRR",
        "RRRRRRR",
        "WWWWWWW",
        "WWWWWWW"
    ]),
    1,  # Expected: YES
    "Multiple overlapping 3x3 blocks"
)

# Test case 5: Isolated cell (NO)
test_case_5 = (
    create_grid_from_strings([
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWRW",
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWWW",
        "WWWWWWW"
    ]),
    0,  # Expected: NO
    "Single isolated red cell"
)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_art_reproduction(dut):
    """Test the art reproduction module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [test_case_1, test_case_2, test_case_3, test_case_4, test_case_5]
    
    passed = 0
    failed = 0
    
    for idx, (grid, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {idx+1}: {description}")
        cocotb.log.info(f"Expected: {'YES' if expected else 'NO'}")
        
        try:
            # Write grid to DUT
            for i in range(GRID_SIZE):
                for j in range(GRID_SIZE):
                    dut.grid[i][j].value = grid[i][j]
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Result mismatch: got {result}, expected {expected}")
            
            cocotb.log.info(f"Result: {'YES' if result else 'NO'} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test failed: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
