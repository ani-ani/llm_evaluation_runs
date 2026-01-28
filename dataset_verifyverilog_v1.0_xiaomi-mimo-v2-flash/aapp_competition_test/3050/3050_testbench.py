import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
CLK_NS = 10
MAX_CYCLES = 1000
DATA_WIDTH = 8
GRID_SIZE = 8
PROG_WIDTH = 4
PROG_SIZE = 16
STATE_BITS = 20  # row(8) + col(8) + pc(4)

# Helpers

def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def clamp_to_width(v, bits):
    mask = (1 << bits) - 1
    return v & mask

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(100, units='ns')
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                return True
        if has_signal(dut, 'valid') and is_value_defined(dut.valid.value):
            if int(dut.valid.value) == 1:
                return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Test case definitions
test_cases = [
    # Sample 1: 6x6 grid, program ">^<^", start (3,4) in 1-indexed -> (2,3) in 0-indexed
    # Expected cycle length 2
    {
        "name": "Sample 1: Cycle length 2",
        "N": 6,
        "prog_str": ">^<^",
        "grid_str": [
            "######",
            "#.#..#",
            "#....#",
            "#..R.#",
            "#....#",
            "######"
        ],
        "expected": 2,  # Cycle length 2
        "is_finite": False
    },
    # Sample 2: 4x4 grid, program "v<^>", start (2,2) in 1-indexed
    # Expected cycle length 4
    {
        "name": "Sample 2: Cycle length 4",
        "N": 4,
        "prog_str": "v<^>",
        "grid_str": [
            "####",
            "#.R#",
            "#..#",
            "####"
        ],
        "expected": 4,
        "is_finite": False
    },
    # Sample 3: 4x4 grid, program "<<<", start (2,2) in 1-indexed
    # Expected finite (hits wall)
    {
        "name": "Sample 3: Finite trail",
        "N": 4,
        "prog_str": "<<<",
        "grid_str": [
            "####",
            "#.R#",
            "#..#",
            "####"
        ],
        "expected": 0,
        "is_finite": True
    },
    # Sample 4: 5x5 grid, program "<<>>", start (2,2) in 1-indexed
    # Expected cycle length 4 (oscillating left/right)
    {
        "name": "Sample 4: Cycle length 4",
        "N": 5,
        "prog_str": "<<>>",
        "grid_str": [
            "#####",
            "#R..#",
            "#####",
            "#####",
            "#####"
        ],
        "expected": 4,
        "is_finite": False
    }
]

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_gl_bot_solver(dut):
    """Test the GL-bot solver module"""
    
    # Setup clock if present
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        cocotb.log.info(f"\nTesting: {tc['name']}")
        try:
            # Prepare program
            prog_map = {'<': 0, '>': 1, '^': 2, 'v': 3}
            prog_vals = [prog_map[c] for c in tc['prog_str']]
            prog_len = len(prog_vals)
            
            # Pad program to PROG_SIZE
            while len(prog_vals) < PROG_SIZE:
                prog_vals.append(0)
            
            # Prepare grid
            # Scale grid to 8x8
            grid_flat = [[0 for _ in range(GRID_SIZE)] for _ in range(GRID_SIZE)]
            start_row = 0
            start_col = 0
            
            # Fill grid from input (scaled)
            for i in range(min(tc['N'], GRID_SIZE)):
                row_str = tc['grid_str'][i]
                for j in range(min(tc['N'], GRID_SIZE)):
                    if j < len(row_str):
                        cell = row_str[j]
                        if cell == '#':
                            grid_flat[i][j] = 1
                        elif cell == 'R':
                            grid_flat[i][j] = 0
                            start_row = i
                            start_col = j
                        else:
                            grid_flat[i][j] = 0
            
            # For our scaled test, ensure borders are walls (already in input)
            # Just clamp coordinates to valid range 1..GRID_SIZE-2
            start_row = clamp_to_width(start_row, 4)
            start_col = clamp_to_width(start_col, 4)
            
            # Assign signals
            if has_signal(dut, 'grid'):
                # Handle packed or unpacked grid
                # Try unpacked first [i][j]
                for i in range(GRID_SIZE):
                    for j in range(GRID_SIZE):
                        try:
                            dut.grid[i][j].value = grid_flat[i][j]
                        except (AttributeError, TypeError):
                            # Try packed
                            pass
                
                # Fallback for packed: construct packed value
                try:
                    packed = 0
                    for i in range(GRID_SIZE):
                        for j in range(GRID_SIZE):
                            packed |= (grid_flat[i][j] << (i * GRID_SIZE + j))
                    dut.grid.value = packed
                except:
                    pass
            
            # Try individual grid ports
            for i in range(GRID_SIZE):
                for j in range(GRID_SIZE):
                    port_name = f'grid_{i}_{j}'
                    if has_signal(dut, port_name):
                        getattr(dut, port_name).value = grid_flat[i][j]
            
            # Assign program
            if has_signal(dut, 'prog'):
                for i in range(PROG_SIZE):
                    try:
                        dut.prog[i].value = prog_vals[i]
                    except (AttributeError, TypeError):
                        pass
            
            # Try individual prog ports
            for i in range(PROG_SIZE):
                port_name = f'prog_{i}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = prog_vals[i]
            
            # Assign other inputs
            if has_signal(dut, 'prog_len'):
                dut.prog_len.value = prog_len
            if has_signal(dut, 'start_row'):
                dut.start_row.value = start_row
            if has_signal(dut, 'start_col'):
                dut.start_col.value = start_col
            
            # Start computation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            result_val = 0
            if has_signal(dut, 'result') and is_value_defined(dut.result.value):
                result_val = int(dut.result.value)
            
            # Decode result
            # 0: finite, 1: cycle 1, 2: cycle 2, 3: cycle 4
            # Expected from test case
            expected_val = tc['expected']
            
            # Map expected cycle length to result code
            if tc['is_finite']:
                expected_code = 0
            elif expected_val == 1:
                expected_code = 1
            elif expected_val == 2:
                expected_code = 2
            elif expected_val == 4:
                expected_code = 3
            else:
                expected_code = 0
            
            if result_val != expected_code:
                raise TestFailure(f"Expected result code {expected_code}, got {result_val}")
            
            # Also check if valid flag is set
            if has_signal(dut, 'valid') and is_value_defined(dut.valid.value):
                if int(dut.valid.value) != 1:
                    raise TestFailure("Valid flag not set")
            
            cocotb.log.info(f"PASS: {tc['name']} - Result: {result_val}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {tc['name']} - {e}")
            failed += 1
    
    cocotb.log.info(f"\nSummary: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} test(s) failed")