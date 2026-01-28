import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0: return 0
    if v > max_val: return max_val
    return v

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Grid writing helper
async def write_grid(dut, grid_str):
    lines = grid_str.strip().split('\n')
    # Assuming R and C are parsed from first line, but here we pass the grid string directly
    # We need to know R and C. Let's assume the testbench parses them.
    # The DUT expects a stream of (row, col, is_bomb).
    # Let's reset the grid valid signals first if needed.
    
    rows = len(lines)
    cols = len(lines[0]) if rows > 0 else 0
    
    dut.grid_valid.value = 1
    
    for r in range(rows):
        for c in range(cols):
            dut.grid_row.value = r
            dut.grid_col.value = c
            dut.is_bomb.value = 1 if lines[r][c] == 'x' else 0
            await RisingEdge(dut.clk)
            
    dut.grid_valid.value = 0
    # Wait a cycle to latch last input
    await RisingEdge(dut.clk)

# Python solution for verification
def solve_python(R, C, grid):
    adj = [[] for _ in range(R)]
    for r in range(R):
        for c in range(C):
            if grid[r][c] == 'x':
                adj[r].append(c)
    
    match_r = [-1] * R
    match_c = [-1] * C
    
    def dfs(u, seen):
        for v in adj[u]:
            if seen[v]:
                continue
            seen[v] = True
            if match_c[v] == -1 or dfs(match_c[v], seen):
                match_c[v] = u
                match_r[u] = v
                return True
        return False
    
    result = 0
    for u in range(R):
        seen = [False] * C
        if dfs(u, seen):
            result += 1
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bombs(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    # Case 1: 3x3
    R1, C1 = 3, 3
    grid1 = ["x..", ".x.", "x.x"]
    expected1 = solve_python(R1, C1, grid1)
    
    # Case 2: 3x4
    R2, C2 = 3, 4
    grid2_str = ".xx.\nx...\nx..x"
    # Let's parse R2, C2 from the input format if the DUT expects it,
    # or just write the grid. The DUT spec implies it processes the grid.
    # Assuming the DUT knows R and C from parameters or hardcoded max 8.
    
    test_cases = [
        (R1, C1, grid1, expected1, "3x3 Sample"),
        (R2, C2, grid2_str, 3, "3x4 Sample")
    ]
    
    passed = 0
    failed = 0
    
    for i, (R, C, grid, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: {desc}")
        
        # Ensure DUT is ready
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Write Grid
        # The DUT interface expects grid_row, grid_col, is_bomb, grid_valid
        # We write all cells. If R/C are smaller than 8, we might need to write dummy data or the DUT handles it.
        # We write exactly R*C cells.
        
        dut.grid_valid.value = 1
        rows = R
        cols = C
        
        # If grid is string, convert
        if isinstance(grid, str):
            grid = grid.strip().split('\n')
        
        for r in range(rows):
            for c in range(cols):
                dut.grid_row.value = r
                dut.grid_col.value = c
                dut.is_bomb.value = 1 if grid[r][c] == 'x' else 0
                await RisingEdge(dut.clk)
        
        dut.grid_valid.value = 0
        # DUT needs to process. It might need a done signal.
        
        try:
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
                
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
