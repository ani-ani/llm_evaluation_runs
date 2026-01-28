import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 2000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_ice_maze(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test case 1: Sample from problem
    grid1 = [
        "#####",
        "#...#",
        "#_###",
        "#_M.#",
        "#__.#",
        "#####"
    ]
    
    expected1 = [
        [-1, -1, -1, -1, -1],
        [-1, 4, 5, 6, -1],
        [-1, 4, -1, -1, -1],
        [-1, 1, 0, 1, -1],
        [-1, 3, 1, 2, -1],
        [-1, -1, -1, -1, -1]
    ]
    
    # Test case 2: Ice slide path
    grid2 = [
        "#####",
        "##__#",
        "##__#",
        "##M_#",
        "##_##",
        "#####"
    ]
    
    expected2 = [
        [-1, -1, -1, -1, -1],
        [-1, -1, 1, 2, -1],
        [-1, -1, 1, 2, -1],
        [-1, -1, 0, 1, -1],
        [-1, -1, 1, -1, -1],
        [-1, -1, -1, -1, -1]
    ]
    
    test_cases = [
        (grid1, expected1, "Sample 1"),
        (grid2, expected2, "Sample 2")
    ]
    
    for test_idx, (grid, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx+1}: {desc}")
        
        # Parse grid: find M position
        goal_row, goal_col = -1, -1
        for r in range(6):
            for c in range(5):
                if grid[r][c] == 'M':
                    goal_row, goal_col = r, c
        cocotb.log.info(f"Goal at ({goal_row}, {goal_col})")
        
        # Write grid to DUT
        if has_signal(dut, 'grid'):
            # Individual element assignment
            for r in range(ARRAY_SIZE):
                for c in range(ARRAY_SIZE):
                    if r < len(grid) and c < len(grid[0]):
                        val = ord(grid[r][c])
                    else:
                        val = ord('#')  # Out of bounds = obstacle
                    dut.grid[r][c].value = clamp_to_width(val, DATA_WIDTH)
        else:
            # Check for individual signals
            for r in range(ARRAY_SIZE):
                for c in range(ARRAY_SIZE):
                    sig_name = f'grid_{r}_{c}'
                    if has_signal(dut, sig_name):
                        if r < len(grid) and c < len(grid[0]):
                            val = ord(grid[r][c])
                        else:
                            val = ord('#')
                        getattr(dut, sig_name).value = clamp_to_width(val, DATA_WIDTH)
        
        # Start computation
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')
        
        # Read results
        passed = True
        for r in range(ARRAY_SIZE):
            for c in range(ARRAY_SIZE):
                # Read result[r][c]
                result_val = None
                if has_signal(dut, 'result'):
                    # Try to access as 2D array
                    if hasattr(dut.result, '__getitem__'):
                        try:
                            result_val = int(dut.result[r][c].value)
                        except:
                            result_val = None
                
                # Fallback to individual signals
                if result_val is None:
                    sig_name = f'result_{r}_{c}'
                    if has_signal(dut, sig_name):
                        result_val = int(getattr(dut, sig_name).value)
                
                if result_val is None:
                    # Skip if no such signal (padding)
                    continue
                
                # Convert to signed if negative expected
                if result_val >= (1 << 15):  # Assuming 16-bit signed
                    result_val = result_val - (1 << 16)
                
                if r < len(grid) and c < len(grid[0]):
                    exp = expected[r][c]
                    if result_val != exp:
                        cocotb.log.error(f"FAIL: result[{r}][{c}] = {result_val}, expected {exp}")
                        passed = False
        
        if not passed:
            raise TestFailure(f"Test {desc} failed")
        cocotb.log.info(f"PASS: {desc}")
    
    cocotb.log.info("All tests passed!")
