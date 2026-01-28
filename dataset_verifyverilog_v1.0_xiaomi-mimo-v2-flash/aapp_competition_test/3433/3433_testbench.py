import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def encode_map(grid_str, rows, cols):
    # Converts ASCII grid string to bit vectors
    wall_vec = 0
    joe_vec = 0
    fire_vec = 0
    lines = grid_str.strip().split('\n')
    # Skip first line (R C) if present, usually input has it. 
    # The input format in prompt shows R C on first line.
    # We assume input to this function is just the grid rows.
    r_idx = 0
    for line in lines:
        if r_idx >= rows: break
        for c_idx, char in enumerate(line[:cols]):
            idx = r_idx * cols + c_idx
            if char == '#':
                wall_vec |= (1 << idx)
            elif char == 'J':
                joe_vec |= (1 << idx)
            elif char == 'F':
                fire_vec |= (1 << idx)
        r_idx += 1
    return wall_vec, joe_vec, fire_vec

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_maze_escape(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Test Case 1: Sample Input 1
    # 4x4 grid
    # ####
    # #JF#
    # #..#
    # #..#
    # Output expected: 3
    grid1 = "####\n#JF#\n#..#\n#..#"
    wall1, joe1, fire1 = encode_map(grid1, 4, 4)
    
    dut.wall_map.value = wall1
    dut.joe_start_map.value = joe1
    dut.fire_start_map.value = fire1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    # 255 is IMPOSSIBLE indicator
    if result == 255:
        raise TestFailure(f"Test 1 failed: Got IMPOSSIBLE, expected 3")
    if result != 3:
        raise TestFailure(f"Test 1 failed: Got {result}, expected 3")
    cocotb.log.info(f"Test 1 passed: Result {result}")
    
    await reset_dut(dut)
    
    # Test Case 2: Sample Input 2
    # 3x3 grid
    # ###
    # #J.
    # #.F
    # Output expected: IMPOSSIBLE
    grid2 = "###\n#J.\n#.F"
    wall2, joe2, fire2 = encode_map(grid2, 3, 3)
    
    dut.wall_map.value = wall2
    dut.joe_start_map.value = joe2
    dut.fire_start_map.value = fire2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    if result != 255:
        raise TestFailure(f"Test 2 failed: Got {result}, expected 255 (IMPOSSIBLE)")
    cocotb.log.info(f"Test 2 passed: Result {result} (IMPOSSIBLE)")
    
    # Test Case 3: Edge case - Joe starts on border
    # 1x1
    # J
    # Output: 0
    grid3 = "J"
    wall3, joe3, fire3 = encode_map(grid3, 1, 1)
    
    dut.wall_map.value = wall3
    dut.joe_start_map.value = joe3
    dut.fire_start_map.value = fire3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    if result != 0:
        raise TestFailure(f"Test 3 failed: Got {result}, expected 0")
    cocotb.log.info(f"Test 3 passed: Result {result}")