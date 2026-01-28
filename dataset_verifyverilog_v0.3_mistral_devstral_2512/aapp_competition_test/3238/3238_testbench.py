import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 1
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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

def pack_grid(grid_strings, n, m):
    """Pack grid into 64-bit vector (8x8, row-major)."""
    packed = 0
    for r in range(min(n, 8)):
        for c in range(min(m, 8)):
            if r < len(grid_strings) and c < len(grid_strings[r]):
                if grid_strings[r][c] == '#':
                    packed |= (1 << (r * 8 + c))
    return packed

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_gold_leaf_fold(dut):
    """Test the gold leaf fold finder module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        # Case 1: Horizontal fold
        {
            'n': 8, 'm': 10,
            'grid': [
                "#.#..##..#",
                "####..####",
                "###.##....",
                "...#..####",
                "....##....",
                ".#.##..##.",
                "##########",
                "##########"
            ],
            'expected': (3, 1, 3, 10)
        },
        # Case 2: Vertical fold
        {
            'n': 5, 'm': 20,
            'grid': [
                "###########.#.#.#.#.",
                "###########...#.###.",
                "##########..##.#..##",
                "###########..#.#.##.",
                "###########.###...#."
            ],
            'expected': (1, 15, 5, 15)
        },
        # Case 3: Diagonal fold
        {
            'n': 5, 'm': 5,
            'grid': [
                ".####",
                "###.#",
                "##..#",
                "#..##",
                "#####"
            ],
            'expected': (4, 1, 1, 4)
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, test in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={test['n']}, m={test['m']}")
        
        # Pack grid
        packed_grid = pack_grid(test['grid'], test['n'], test['m'])
        
        # Set inputs
        dut.n.value = test['n']
        dut.m.value = test['m']
        dut.grid.value = packed_grid
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read results
        if not all(is_value_defined(dut.r1.value), is_value_defined(dut.c1.value),
                   is_value_defined(dut.r2.value), is_value_defined(dut.c2.value)):
            cocotb.log.error(f"  FAIL: Output signals undefined")
            failed += 1
            continue
        
        r1 = int(dut.r1.value)
        c1 = int(dut.c1.value)
        r2 = int(dut.r2.value)
        c2 = int(dut.c2.value)
        
        # Check against expected (considering tolerance for diagonal simplification)
        exp_r1, exp_c1, exp_r2, exp_c2 = test['expected']
        
        # Allow small deviations due to simplified diagonal handling
        if (r1, c1, r2, c2) == (exp_r1, exp_c1, exp_r2, exp_c2) or \
           (r1, c1, r2, c2) == (exp_r1, exp_c1, exp_r2, exp_c2):  # Add more conditions if needed
            cocotb.log.info(f"  PASS: ({r1}, {c1}, {r2}, {c2})")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: Expected ({exp_r1}, {exp_c1}, {exp_r2}, {exp_c2}), got ({r1}, {c1}, {r2}, {c2})")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")