import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 2  # 2 bits per color (R=0, G=1, B=2, W=3)
GRID_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_grid(dut, grid):
    """Write 8x8 grid (list of lists) to DUT target signals"""
    for i in range(GRID_SIZE):
        for j in range(GRID_SIZE):
            color_val = grid[i][j]
            if color_val == 'R': v = 0
            elif color_val == 'G': v = 1
            elif color_val == 'B': v = 2
            elif color_val == 'W': v = 3
            else: v = 3  # default white
            # Handle both possible array access patterns
            if has_signal(dut, f'target_{i}_{j}'):
                getattr(dut, f'target_{i}_{j}').value = clamp_to_width(v, DATA_WIDTH)
            elif hasattr(dut.target, '__getitem__'):
                dut.target[i][j].value = clamp_to_width(v, DATA_WIDTH)

async def set_grid_size(dut, rows, cols):
    """Set actual grid dimensions"""
    if has_signal(dut, 'rows'):
        dut.rows.value = clamp_to_width(rows, 4)
    if has_signal(dut, 'cols'):
        dut.cols.value = clamp_to_width(cols, 4)

# Test case definitions
test_cases = [
    {
        "name": "Sample 1: YES (4x5)",
        "grid": [
            "WRRRG",
            "WRRRG",
            "WRRRG",
            "WBBBB",
            "WWWWW",  # Padding for 8x8
            "WWWWW",
            "WWWWW",
            "WWWWW"
        ],
        "rows": 4,
        "cols": 5,
        "expected": 1  # YES
    },
    {
        "name": "Sample 2: NO (3x4)",
        "grid": [
            "WWRR",
            "WRRR",
            "WRRR",
            "WWWW",  # Padding
            "WWWW",
            "WWWW",
            "WWWW",
            "WWWW"
        ],
        "rows": 3,
        "cols": 4,
        "expected": 0  # NO
    },
    {
        "name": "Sample 3: All White (3x3)",
        "grid": [
            "WWW",
            "WWW",
            "WWW",
            "WWWWWWWW",
            "WWWWWWWW",
            "WWWWWWWW",
            "WWWWWWWW",
            "WWWWWWWW"
        ],
        "rows": 3,
        "cols": 3,
        "expected": 1  # YES
    },
    {
        "name": "Full 8x8 Single Color",
        "grid": [
            "RRRRRRRR",
            "RRRRRRRR",
            "RRRRRRRR",
            "RRRRRRRR",
            "RRRRRRRR",
            "RRRRRRRR",
            "RRRRRRRR",
            "RRRRRRRR"
        ],
        "rows": 8,
        "cols": 8,
        "expected": 1  # YES (all cells in valid 3x3 blocks)
    },
    {
        "name": "Single Red Cell (impossible)",
        "grid": [
            "WWWWWWWW",
            "WWWWWWWW",
            "WWWWWWWW",
            "WWWRWWWW",
            "WWWWWWWW",
            "WWWWWWWW",
            "WWWWWWWW",
            "WWWWWWWW"
        ],
        "rows": 8,
        "cols": 8,
        "expected": 0  # NO (single red not in 3x3 block)
    },
    {
        "name": "Mixed but valid",
        "grid": [
            "WWWWWWWW",
            "WWWWWWWW",
            "WWWWWWWW",
            "WWWWWRRR",
            "WWWWWRRR",
            "WWWWWRRR",
            "WWWWWWWW",
            "WWWWWWWW"
        ],
        "rows": 8,
        "cols": 8,
        "expected": 1  # YES (RRR block is valid 3x3)
    }
]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_grid_stamp_checker(dut):
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Setup clock and reset
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for test in test_cases:
        cocotb.log.info(f"\n=== Test: {test['name']} ===")
        try:
            # Write grid data
            await write_grid(dut, test['grid'])
            
            # Set dimensions
            await set_grid_size(dut, test['rows'], test['cols'])
            
            if is_seq:
                # Start processing
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result = int(dut.result.value)
                
                # Check against expected
                if result != test['expected']:
                    raise TestFailure(
                        f"Expected {'YES' if test['expected'] else 'NO'}, "
                        f"got {'YES' if result else 'NO'}"
                    )
            else:
                # Combinational - just wait
                await Timer(100, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                result = int(dut.result.value)
                if result != test['expected']:
                    raise TestFailure(
                        f"Expected {test['expected']}, got {result}"
                    )
            
            passed += 1
            cocotb.log.info(f"PASS: {test['name']}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {test['name']} - {e}")
            failed += 1
    
    # Final result
    cocotb.log.info(f"\n=== Results: {passed} passed, {failed} failed ===")
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")