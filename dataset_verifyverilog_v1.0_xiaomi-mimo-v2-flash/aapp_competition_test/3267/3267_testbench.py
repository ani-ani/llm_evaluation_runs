import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 2
ARRAY_SIZE = 16  # Max rows/cols
MAX_PIECES = 8
CLK_NS = 10
MAX_CYCLES = 1000

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_board(grid_lines, rows, cols):
    # grid_lines is list of strings
    # Returns packed integer for board_flat
    # Map: 'M' -> 2 (10b), 'S' -> 1 (01b), '.' -> 0 (00b)
    packed = 0
    for r in range(rows):
        for c in range(cols):
            char = grid_lines[r][c]
            val = 0
            if char == 'M': val = 2
            elif char == 'S': val = 1
            # index = r * 16 + c (assuming fixed 16 cols for packing)
            index = r * 16 + c
            packed |= (val << (index * 2))
    return packed

def calculate_expected(grid_lines, rows, cols, player_char):
    # Extract coordinates
    coords = []
    for r in range(rows):
        for c in range(cols):
            if grid_lines[r][c] == player_char:
                coords.append((r, c))
    
    if len(coords) < 2:
        return 0
    
    total_spread = 0
    n = len(coords)
    for i in range(n):
        for j in range(i + 1, n):
            r1, c1 = coords[i]
            r2, c2 = coords[j]
            # Chebyshev distance
            dist = max(abs(r1 - r2), abs(c1 - c2))
            total_spread += dist
    return total_spread

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_spread_module(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test Cases
    test_cases = [
        {
            "grid": [
                "SMS..............",
                "MMS.............."
            ],
            "rows": 2, "cols": 3,
            "exp_mirko": 3, "exp_slavko": 5,
            "desc": "Example 1: 2x3"
        },
        {
            "grid": [
                "S.M..............",
                "M................"
            ],
            "rows": 2, "cols": 3,
            "exp_mirko": 2, "exp_slavko": 0,
            "desc": "Example 2: 2x3"
        },
        {
            "grid": [
                "M................",
                "..S.M............",
                "SS..S............",
                ".M................"
            ],
            "rows": 4, "cols": 5,
            "exp_mirko": 10, "exp_slavko": 13,
            "desc": "Example 3: 4x5"
        }
    ]

    passed = 0
    failed = 0

    for tc in test_cases:
        cocotb.log.info(f"Running test: {tc['desc']}")
        
        # Prepare inputs
        # board_flat expects 256 bits (64 x 2-bit chunks for 16x16 grid)
        # We only fill the first rows*cols chunks
        packed_val = pack_board(tc['grid'], tc['rows'], tc['cols'])
        
        # Drive inputs
        if has_signal(dut, 'board_flat'):
            dut.board_flat.value = packed_val
        else:
            # Fallback if individual signals (unlikely based on spec but safe)
            cocotb.log.error("board_flat signal missing")
            failed += 1
            continue

        # Trigger
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            await Timer(100, units='ns')
        
        # Wait for result
        try:
            if has_signal(dut, 'done'):
                await wait_for_done(dut)
            else:
                await Timer(500, units='ns') # Combinational delay
            
            # Read Results
            mirko_res = 0
            slavko_res = 0
            
            if has_signal(dut, 'mirko_spread'):
                mirko_res = int(dut.mirko_spread.value)
            if has_signal(dut, 'slavko_spread'):
                slavko_res = int(dut.slavko_spread.value)
            
            # Validate
            if mirko_res != tc['exp_mirko']:
                raise TestFailure(f"Mirko spread mismatch: Expected {tc['exp_mirko']}, got {mirko_res}")
            if slavko_res != tc['exp_slavko']:
                raise TestFailure(f"Slavko spread mismatch: Expected {tc['exp_slavko']}, got {slavko_res}")
            
            cocotb.log.info(f"PASS: {tc['desc']} (M={mirko_res}, S={slavko_res})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {tc['desc']} - {e}")
            failed += 1
        
        # Prepare for next test (reset inputs)
        if has_signal(dut, 'start'):
            dut.start.value = 0
        await RisingEdge(dut.clk)

    if failed > 0:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
