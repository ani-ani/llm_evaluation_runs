import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_grid(dut, grid, H, W):
    # Flatten the 2D grid into the flat vector
    flat_grid = 0
    for r in range(H):
        for c in range(W):
            # Assuming input grid is 0 for open, 1 for blocked (matching prompt)
            cell = grid[r][c]
            bit_pos = r * 16 + c
            if cell:
                flat_grid |= (1 << bit_pos)
    dut.grid_in.value = flat_grid
    dut.H.value = H
    dut.W.value = W

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_min_block_cells(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (grid, H, W, expected_result)
    # Grid is 0=open, 1=blocked
    # Example 1: 2x2 all open -> need to block 2
    grid1 = [[0, 0], [0, 0]]
    
    # Example 2: 3x4 with a wall in middle
    # ....
    # .##.
    # ....
    # Paths go through (1,0), (2,0), (0,1), etc. The walls block middle.
    # Diagonals: (0,0), (0,1),(1,0), (0,2),(1,1),(2,0), ...
    # Reachable set intersection might yield a single point or need 2.
    grid2 = [[0, 0, 0, 0], 
             [0, 1, 1, 0], 
             [0, 0, 0, 0]]
    # Expected output: 2 based on problem statement example 3
    
    # Example 3: 1x1 (though problem says n*m >= 3, let's test simple)
    # grid3 = [[0]] -> 0 (start=end)
    
    # Example 4: Path completely blocked
    grid4 = [[0, 1], 
             [1, 0]]
    # Expected: 0
    
    # Example 5: Single bottleneck (Example 2 from prompt)
    # 4x4 grid
    # ....
    # #.#.
    # ....
    # .#..
    # This might have a bottleneck or need 1.
    
    test_cases = [
        (grid1, 2, 2, 2, "2x2 open"),
        (grid2, 3, 4, 2, "3x4 wall"),
        (grid4, 2, 2, 0, "Blocked"),
    ]
    
    passed = 0
    failed = 0
    
    for grid, H, W, expected, desc in test_cases:
        cocotb.log.info(f"Testing: {desc}")
        
        # Write inputs
        await write_grid(dut, grid, H, W)
        
        # Assert start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"FAIL: {desc} - Result undefined")
            failed += 1
            continue
            
        result = int(dut.result.value)
        if result != expected:
            cocotb.log.error(f"FAIL: {desc} - Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"PASS: {desc} - Got {result}")
            passed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
