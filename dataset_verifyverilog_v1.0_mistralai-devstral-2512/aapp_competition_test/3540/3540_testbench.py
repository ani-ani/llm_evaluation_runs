import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 2
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 10000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Helper to encode grid to 2-bit values
def encode_color(c):
    if c == 'R': return 0
    if c == 'G': return 1
    if c == 'B': return 2
    if c == 'Y': return 3
    return 0

# Helper to map input string to values
def parse_grid(input_str):
    lines = input_str.strip().split('\n')
    values = []
    for line in lines:
        for char in line.strip():
            values.append(encode_color(char))
    return values

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_torus_puzzle(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from the problem
    test_cases = [
        ("RGGR\nGBGB\nBYBY\nYRYR", 3),
        ("RRRR\nGBGG\nGYBB\nBYYY", 4)
    ]
    
    for i, (input_str, expected_moves) in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: Input grid, expected moves={expected_moves}")
        
        # Parse input
        values = parse_grid(input_str)
        
        # Write to grid array
        # Assuming dut.grid is an array of signals, e.g., dut.grid[0], dut.grid[1], ...
        for idx, val in enumerate(values):
            if has_signal(dut, f'grid_{idx}'):
                getattr(dut, f'grid_{idx}').value = val
            elif hasattr(dut.grid, '__getitem__'):
                dut.grid[idx].value = val
            else:
                raise TestFailure(f"Cannot access grid index {idx}")
        
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.moves.value):
                raise TestFailure("Result moves is undefined")
            
            result = int(dut.moves.value)
            
            # Check result (allowing for 15 if unsolved, though problem guarantees solvable)
            if result != expected_moves:
                # If result is 15, it means not found (maybe BFS incomplete)
                # For this benchmark, we expect correct implementation
                raise TestFailure(f"Expected {expected_moves}, got {result}")
            
            cocotb.log.info(f"Pass: Got {result}")
        else:
            # Combinational logic (unlikely)
            await Timer(100, units='ns')
            if not is_value_defined(dut.moves.value):
                raise TestFailure("Result undefined")
            result = int(dut.moves.value)
            if result != expected_moves:
                raise TestFailure(f"Expected {expected_moves}, got {result}")
    
    cocotb.log.info("All tests passed!")
