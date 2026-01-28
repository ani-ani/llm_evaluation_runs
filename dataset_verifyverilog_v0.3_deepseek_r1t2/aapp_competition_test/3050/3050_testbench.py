import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
GRID_SIZE = 8
STRING_LEN = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000

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
# PROBLEM-SPECIFIC HELPER FUNCTIONS
# ============================================================================

def encode_program(prog_string):
    """Encode program string into 32-bit value (8 chars × 4 bits)."""
    # < = 0, > = 1, ^ = 2, v = 3
    char_map = {'<': 0, '>': 1, '^': 2, 'v': 3}
    encoded = 0
    for i, char in enumerate(prog_string[:STRING_LEN]):
        encoded |= (char_map[char] << (4 * i))
    return encoded

def grid_to_bitmap(grid_lines):
    """Convert grid lines to 64-bit bitmap (8x8)."""
    # Each bit: 1=passable (.), 0=blocked (# or R at start)
    bitmap = 0
    for r in range(GRID_SIZE):
        for c in range(GRID_SIZE):
            # Note: original grid has # on borders, we ignore those for our 8x8
            # For our scaled version, we just treat '.' as passable
            char = grid_lines[r][c]
            if char in '.R':
                bitmap |= (1 << (r * GRID_SIZE + c))
    return bitmap

def find_start_pos(grid_lines):
    """Find the position of 'R' in the grid."""
    for r in range(GRID_SIZE):
        for c in range(GRID_SIZE):
            if grid_lines[r][c] == 'R':
                return (r << 3) | c  # {row[2:0], col[2:0]}
    return 0

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
async def test_robot_movement(dut):
    """Test the robot movement module with scaled-down examples."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases (scaled down from original)
    # We map original examples to 8x8 grid
    test_cases = [
        {
            'name': 'Example 1: Cycle length 2',
            'grid': [
                "########",
                "#.#..#.#",
                "#....#.#",
                "#..R.#.#",
                "#....#.#",
                "########",
                "########",
                "########"
            ],
            'program': '>^<^',
            'expected': 2
        },
        {
            'name': 'Example 2: Cycle length 4',
            'grid': [
                "########",
                "#.R#....",
                "#..#....",
                "########",
                "########",
                "########",
                "########",
                "########"
            ],
            'program': 'v<^>',
            'expected': 4
        },
        {
            'name': 'Example 3: Finite trail',
            'grid': [
                "########",
                "#.R#....",
                "#..#....",
                "########",
                "########",
                "########",
                "########",
                "########"
            ],
            'program': '<<<',
            'expected': 1
        },
        {
            'name': 'Example 4: Cycle length 4',
            'grid': [
                "########",
                "#R..#...",
                "########",
                "########",
                "########",
                "########",
                "########",
                "########"
            ],
            'program': '<<>>',
            'expected': 4
        }
    ]
    
    passed = 0
    failed = 0
    
    for test in test_cases:
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Running: {test['name']}")
        cocotb.log.info(f"Program: {test['program']}")
        
        try:
            # Encode inputs
            grid_bitmap = grid_to_bitmap(test['grid'])
            program_encoded = encode_program(test['program'])
            start_position = find_start_pos(test['grid'])
            prog_len = len(test['program'])
            
            cocotb.log.info(f"Grid bitmap: 0x{grid_bitmap:016X}")
            cocotb.log.info(f"Program encoded: 0x{program_encoded:08X}")
            cocotb.log.info(f"Start pos: row={start_position>>3}, col={start_position&0x7}")
            cocotb.log.info(f"Program length: {prog_len}")
            
            # Assign inputs
            dut.grid_data.value = grid_bitmap
            dut.program.value = program_encoded
            dut.start_pos.value = start_position
            dut.prog_len.value = prog_len
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            expected = test['expected']
            
            cocotb.log.info(f"Result: {result}, Expected: {expected}")
            
            if result == expected:
                cocotb.log.info("  PASS")
                passed += 1
            else:
                cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
                failed += 1
            
            # Wait a few cycles before next test
            await Timer(100, units='ns')
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"FINAL RESULTS: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")