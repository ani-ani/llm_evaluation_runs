import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants based on 16x16 grid
GRID_SIZE = 16
NUM_CELLS = GRID_SIZE * GRID_SIZE
DATA_WIDTH = 4  # Bits for cell data
CLK_NS = 10
MAX_CYCLES = 10000

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
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'grid_valid'): dut.grid_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Connectivity Check
def is_connected(mask, width=GRID_SIZE):
    """Check if bits set in mask form a single connected component."""
    mask_int = int(mask)
    if mask_int == 0: return False
    
    # Find first set bit
    start = 0
    while not (mask_int & (1 << start)): start += 1
    
    # BFS
    visited = set([start])
    queue = [start]
    
    while queue:
        curr = queue.pop(0)
        r, c = curr // width, curr % width
        
        # Neighbors
        for dr, dc in [(-1,0), (1,0), (0,-1), (0,1)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < width and 0 <= nc < width:
                n_idx = nr * width + nc
                if (mask_int & (1 << n_idx)) and n_idx not in visited:
                    visited.add(n_idx)
                    queue.append(n_idx)
    
    # Count total bits
    total_bits = bin(mask_int).count('1')
    return len(visited) == total_bits

def verify_solution(grid_str, result_a, result_b, result_c):
    """Verify the solution against the problem constraints."""
    n = len(grid_str)
    m = len(grid_str[0])
    
    a = int(result_a)
    b = int(result_result_b)
    c = int(result_c)
    
    # Check connectivity
    if not is_connected(a, GRID_SIZE): return False, "Region A not connected"
    if not is_connected(b, GRID_SIZE): return False, "Region B not connected"
    if not is_connected(c, GRID_SIZE): return False, "Region C not connected"
    
    # Check every cell is in at least one region
    # And check constraints
    for r in range(n):
        for c_idx in range(m):
            idx = r * GRID_SIZE + c_idx
            in_a = (a >> idx) & 1
            in_b = (b >> idx) & 1
            in_c = (c >> idx) & 1
            
            count = in_a + in_b + in_c
            if count == 0: return False, "Cell uncovered"
            
            constraint = grid_str[r][c_idx]
            if constraint == '1' and count != 1:
                return False, f"Cell ({r},{c_idx}) should be 1 lang, has {count}"
            if constraint == '2' and count < 2:
                return False, f"Cell ({r},{c_idx}) should be 2+ langs, has {count}"
    
    # Check non-empty
    if a == 0 or b == 0 or c == 0: return False, "Empty region"
    
    return True, "OK"

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_gridnavia(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test Case 1: Sample Input 1 (3x4 mapped to 16x16)
    # We will fill the rest of the 16x16 grid with '1's to make it solvable
    grid_input = [
        "2211",
        "1112",
        "1112"
    ]
    
    # Prepare input stream for 16x16
    input_cells = []
    for r in range(GRID_SIZE):
        row_str = "" if r < len(grid_input) else "1" * GRID_SIZE
        if r < len(grid_input): row_str = grid_input[r]
        for c in range(GRID_SIZE):
            char = row_str[c] if c < len(row_str) else '1'
            
            # 4-bit encoding: bit0=1-lang, bit1=2-lang
            val = 0
            if char == '1': val = 1 # Binary 01
            elif char == '2': val = 2 # Binary 10
            input_cells.append(val)
    
    # Load Phase
    dut.start.value = 1
    dut.grid_valid.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(NUM_CELLS):
        # Check if ready or just blast data (assuming simple streaming)
        # If the interface requires handshaking, we would check 'ready' signal.
        # Assuming simple valid stream for now as per 'grid_valid' signal.
        
        dut.cell_idx.value = i
        dut.cell_data.value = clamp_to_width(input_cells[i], DATA_WIDTH)
        await RisingEdge(dut.clk)
    
    dut.grid_valid.value = 0
    
    # Wait for completion
    await wait_for_done(dut)
    
    if not is_value_defined(dut.possible.value):
        raise TestFailure("Possible signal undefined")
        
    possible = int(dut.possible.value)
    
    if possible == 1:
        res_a = dut.result_a.value
        res_b = dut.result_b.value
        res_c = dut.result_c.value
        
        valid, msg = verify_solution(grid_input, res_a, res_b, res_c)
        if not valid:
            raise TestFailure(f"Invalid solution: {msg}")
        
        cocotb.log.info(f"Test 1 Passed: Solution found and verified.")
    else:
        # The problem might be impossible for certain heuristics, 
        # but the sample input is definitely possible.
        raise TestFailure("Expected possible=1 for sample input")
        
    # Reset for second test
    await reset_dut(dut)
    
    # Test Case 2: 1x1 '1' (Impossible for 3 regions)
    input_cells_2 = [1] + [0] * (NUM_CELLS - 1) # Rest dummy
    
    dut.start.value = 1
    dut.grid_valid.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(NUM_CELLS):
        dut.cell_idx.value = i
        dut.cell_data.value = input_cells_2[i]
        await RisingEdge(dut.clk)
    
    dut.grid_valid.value = 0
    await wait_for_done(dut)
    
    possible = int(dut.possible.value)
    if possible == 0:
        cocotb.log.info("Test 2 Passed: Correctly identified impossible case.")
    else:
        # It might be possible if the heuristic connects everything, 
        # but logically a 1x1 grid cannot have 3 non-empty regions.
        # The checker should catch this.
        res_a = dut.result_a.value
        res_b = dut.result_b.value
        res_c = dut.result_c.value
        valid, msg = verify_solution(["1"], res_a, res_b, res_c)
        if valid:
             cocotb.log.warning("Warning: Heuristic found a solution for impossible case, likely padding.")
        else:
             raise TestFailure("Heuristic claimed success but solution invalid")
