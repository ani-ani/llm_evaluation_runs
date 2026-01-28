import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def wait_for_done(dut, max_cycles=3000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Constants
GRID_W, GRID_H = 16, 16
DATA_WIDTH = 8

# Terrain Encoding
EMPTY = 0
FOREST = 1
MOUNTAIN = 2
RIVER = 3
START = 4
GOAL = 5

async def load_grid(dut, map_str, K):
    lines = map_str.strip().split('\n')
    N = len(lines)
    M = len(lines[0]) if N > 0 else 0
    
    # Initialize grid with RIVER (impassable) for out of bounds or pads
    for r in range(GRID_H):
        for c in range(GRID_W):
            dut.grid[r * GRID_W + c].value = RIVER

    # Load actual map
    start_r, start_c = -1, -1
    goal_r, goal_c = -1, -1
    
    for r in range(min(N, GRID_H)):
        for c in range(min(M, GRID_W)):
            char = lines[r][c]
            val = EMPTY
            if char == '.': val = EMPTY
            elif char == 'F': val = FOREST
            elif char == 'M': val = MOUNTAIN
            elif char == '#': val = RIVER
            elif char == 'S': 
                val = START
                start_r, start_c = r, c
            elif char == 'G': 
                val = GOAL
                goal_r, goal_c = r, c
            else: continue
            
            dut.grid[r * GRID_W + c].value = val
    
    dut.K.value = K
    return N, M, start_r, start_c, goal_r, goal_c

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_treasure_hunt(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test Cases
    test_cases = [
        ("2 5 4\nS#.F.\n.MFMG", 4, 3),
        ("1 2 1\nGS", 1, 1),
        ("2 2 10\nS#\n#G", 10, 255), # -1 maps to 255 for 8-bit
        ("1 7 4\nSMMMMMG", 4, 5)
    ]

    for i, (map_str, K, expected_days) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: Expected Days={expected_days}")
        
        # Load inputs
        N, M, s_r, s_c, g_r, g_c = await load_grid(dut, map_str, K)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check Result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result signal undefined")
            
        result = int(dut.result.value)
        
        # Handle -1 mapping (assuming 255 is used for impossibility in 8-bit)
        if expected_days == -1:
            expected = 255
        else:
            expected = expected_days
            
        if result != expected:
            raise TestFailure(f"Test {i+1} Failed: Expected {expected_days}, got {result}")
        
        # Reset for next test
        await reset_dut(dut)