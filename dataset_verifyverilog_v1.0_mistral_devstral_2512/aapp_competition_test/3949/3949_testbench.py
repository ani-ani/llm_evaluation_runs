import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 1  # Each cell is 1 bit
GRID_ROWS = 8
GRID_COLS = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

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

def pack_row(row):
    """Pack a row string into an 8-bit value."""
    val = 0
    for j, char in enumerate(row):
        if j < 8 and char == '#':
            val |= (1 << (7 - j))  # MSB is column 0
    return val

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def write_grid(dut, grid):
    """Write 8x8 grid to DUT."""
    # grid is list of 8 strings of 8 chars each
    for i in range(GRID_ROWS):
        port_name = f'grid_{i}'
        if has_signal(dut, port_name):
            row_val = pack_row(grid[i])
            getattr(dut, port_name).value = row_val
        else:
            raise TestFailure(f"Cannot find grid port: {port_name}")

async def read_result(dut):
    """Read result from DUT."""
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    return int(dut.result.value)

# ============================================================================
# TEST CASES
# ============================================================================

# Scaled test cases from original problem (8x8 grid)
test_cases = [
    {
        "name": "Example 1: 3x3 pattern with 1 component",
        "grid": [
            ".#.",
            "###",
            "##.",
            ".###.",  # Padding to 8 columns
            ".###.",
            ".###.",
            ".###.",
            ".###.",
        ],
        "expected": 1,
        "should_pass": True
    },
    {
        "name": "Example 2: 4x2 pattern with gap",
        "grid": [
            "##......",
            ".#......",
            ".#......",
            "##......",
            ".#......",
            ".#......",
            ".#......",
            ".#......",
        ],
        "expected": 0xFFFF,  # -1
        "should_pass": False
    },
    {
        "name": "Example 3: 4x5 pattern with 2 components",
        "grid": [
            "....#...",
            "####....",
            ".###....",
            ".#......",
            ".###....",
            ".###....",
            ".###....",
            ".###....",
        ],
        "expected": 2,
        "should_pass": True
    },
    {
        "name": "Example 4: 2x1 pattern with empty row",
        "grid": [
            ".#......",
            "#.......",
            ".#......",
            ".#......",
            ".#......",
            ".#......",
            ".#......",
            ".#......",
        ],
        "expected": 0xFFFF,  # -1
        "should_pass": False
    },
    {
        "name": "Example 5: All white grid",
        "grid": [
            "........",
            "........",
            "........",
            "........",
            "........",
            "........",
            "........",
            "........",
        ],
        "expected": 0,
        "should_pass": True
    },
    {
        "name": "Single black cell",
        "grid": [
            "#.......",
            "........",
            "........",
            "........",
            "........",
            "........",
            "........",
            "........",
        ],
        "expected": 1,
        "should_pass": True
    },
    {
        "name": "Two disconnected components",
        "grid": [
            "#.#.....",
            "........",
            "........",
            "........",
            "........",
            "........",
            "........",
            "........",
        ],
        "expected": 2,
        "should_pass": True
    },
    {
        "name": "Row with gap (invalid)",
        "grid": [
            "#.#.....",
            "........",
            "........",
            "........",
            "........",
            "........",
            "........",
            "........",
        ],
        "expected": 0xFFFF,  # -1
        "should_pass": False
    },
]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_monopole_magnet(dut):
    """Main test for Monopole Magnet problem."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, test_case in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {test_case['name']}")
        cocotb.log.info(f"Grid preview: {test_case['grid'][0]}")
        
        try:
            # Write grid
            await write_grid(dut, test_case['grid'])
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result = await read_result(dut)
            
            # Check result
            expected = test_case['expected']
            if result != expected:
                raise TestFailure(f"Expected {expected:#06x} ({expected if expected != 0xFFFF else -1}), got {result:#06x} ({result if result != 0xFFFF else -1})")
            
            cocotb.log.info(f"  PASS: result = {result if result != 0xFFFF else -1}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
