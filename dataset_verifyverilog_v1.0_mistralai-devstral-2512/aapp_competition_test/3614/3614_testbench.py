import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

DATA_WIDTH = 8
N = 8
CLK_NS = 10
MAX_CYCLES = 2000

def write_grid(dut, grid):
    """Write 8x8 grid to dut.grid array"""
    for r in range(N):
        for c in range(N):
            dut.grid[r][c].value = clamp_to_width(grid[r][c], DATA_WIDTH)

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for i in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_grasshopper(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk') and has_signal(dut, 'rst_n')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test case 1: Example from problem
    # 4x4 grid scaled to 8x8 (repeat pattern)
    grid1 = [
        [1, 2, 3, 4, 1, 2, 3, 4],
        [2, 3, 4, 5, 2, 3, 4, 5],
        [3, 4, 5, 6, 3, 4, 5, 6],
        [4, 5, 6, 7, 4, 5, 6, 7],
        [1, 2, 3, 4, 1, 2, 3, 4],
        [2, 3, 4, 5, 2, 3, 4, 5],
        [3, 4, 5, 6, 3, 4, 5, 6],
        [4, 5, 6, 7, 4, 5, 6, 7]
    ]
    
    # Expected: from (0,0) with values [1,2,3,4,5,6,7] -> path length 4
    # Path: (0,0)=1 -> (1,2)=4 -> (2,4)=3 -> (3,6)=7 (invalid, decreasing)
    # Better: (0,0)=1 -> (1,2)=4 -> (3,3)=5 -> (2,5)=6 -> path length 4
    expected1 = 4
    
    # Test case 2: Simple ascending diagonal
    grid2 = [
        [1, 2, 3, 4, 5, 6, 7, 8],
        [2, 3, 4, 5, 6, 7, 8, 9],
        [3, 4, 5, 6, 7, 8, 9, 10],
        [4, 5, 6, 7, 8, 9, 10, 11],
        [5, 6, 7, 8, 9, 10, 11, 12],
        [6, 7, 8, 9, 10, 11, 12, 13],
        [7, 8, 9, 10, 11, 12, 13, 14],
        [8, 9, 10, 11, 12, 13, 14, 15]
    ]
    expected2 = 8  # Full diagonal possible
    
    # Test case 3: All same values (no jumps possible)
    grid3 = [[5] * 8 for _ in range(8)]
    expected3 = 1  # Only starting position
    
    test_cases = [
        (grid1, 0, 0, expected1, "4x4 pattern from (0,0)"),
        (grid2, 0, 0, expected2, "Ascending diagonal from (0,0)"),
        (grid3, 0, 0, expected3, "All same values from (0,0)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (grid, start_r, start_c, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Write grid
            for r in range(N):
                for c in range(N):
                    if has_signal(dut, f'grid_{r}_{c}'):
                        getattr(dut, f'grid_{r}_{c}').value = clamp_to_width(grid[r][c], DATA_WIDTH)
                    elif hasattr(dut.grid, '__getitem__'):
                        dut.grid[r][c].value = clamp_to_width(grid[r][c], DATA_WIDTH)
                    else:
                        raise TestFailure("Grid signal not found")
            
            # Write start position
            dut.start_r.value = start_r
            dut.start_c.value = start_c
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, MAX_CYCLES)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")
