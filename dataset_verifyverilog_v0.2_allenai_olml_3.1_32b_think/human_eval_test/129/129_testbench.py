import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def grid_to_bytes(grid):
    """Convert 2x2 grid to flattened byte array"""
    return [grid[0][0], grid[0][1], grid[1][0], grid[1][1]]

def simulate_min_path(grid, k):
    """Simulate the pathfinding algorithm in Python"""
    # Get position of value 1 (the minimum)
    pos = None
    for r in range(2):
        for c in range(2):
            if grid[r][c] == 1:
                pos = (r, c)
                break
        if pos:
            break
    
    path = [1]
    current_pos = pos
    
    # Build path step by step
    for step in range(k - 1):
        # Get neighbors
        r, c = current_pos
        neighbors = []
        if r > 0:
            neighbors.append((r-1, c))
        if r < 1:
            neighbors.append((r+1, c))
        if c > 0:
            neighbors.append((r, c-1))
        if c < 1:
            neighbors.append((r, c+1))
        
        # Get values and positions
        candidates = []
        for nr, nc in neighbors:
            val = grid[nr][nc]
            candidates.append((val, nr, nc))
        
        # Sort by value (lexicographic is just value order for single step)
        candidates.sort()
        
        # Choose smallest
        next_val, next_r, next_c = candidates[0]
        path.append(next_val)
        current_pos = (next_r, next_c)
    
    return path

@cocotb.test()
async def test_minPath_basic(dut):
    """Test basic functionality with 2x2 grid"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.grid.value = 0
    dut.k.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: grid = [[1,2],[3,4]], k=10
    grid = [[1, 2], [3, 4]]
    k = 10
    expected = [1, 2, 1, 2, 1, 2, 1, 2, 1, 2]
    
    # Load grid
    flat_grid = grid_to_bytes(grid)
    dut.grid.value = 0
    for i in range(4):
        dut.grid[i].value = flat_grid[i]
    dut.k.value = k
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 200 cycles)
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Check result
    result = []
    for i in range(10):
        val = int(dut.result[i].value)
        if val > 0:
            result.append(val)
    
    print(f"Test 1: Expected {expected}, Got {result}")
    if result != expected:
        raise TestFailure(f"Path mismatch: expected {expected}, got {result}")

@cocotb.test()
async def test_minPath_case2(dut):
    """Test with grid [[1,3],[3,2]], k=10"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    grid = [[1, 3], [3, 2]]
    k = 10
    expected = [1, 3, 1, 3, 1, 3, 1, 3, 1, 3]
    
    flat_grid = grid_to_bytes(grid)
    for i in range(4):
        dut.grid[i].value = flat_grid[i]
    dut.k.value = k
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result = [int(dut.result[i].value) for i in range(10) if int(dut.result[i].value) > 0]
    print(f"Test 2: Expected {expected}, Got {result}")
    if result != expected:
        raise TestFailure(f"Path mismatch: expected {expected}, got {result}")

@cocotb.test()
async def test_minPath_k1(dut):
    """Test k=1 (only minimum value)"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    grid = [[5, 9], [4, 1]]
    k = 1
    expected = [1]
    
    flat_grid = grid_to_bytes(grid)
    for i in range(4):
        dut.grid[i].value = flat_grid[i]
    dut.k.value = k
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result = [int(dut.result[i].value) for i in range(10) if int(dut.result[i].value) > 0]
    print(f"Test 3: Expected {expected}, Got {result}")
    if result != expected:
        raise TestFailure(f"Path mismatch: expected {expected}, got {result}")

@cocotb.test()
async def test_minPath_complex(dut):
    """Test with more complex 2x2 grid"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Grid: [[4, 1], [2, 3]]
    grid = [[4, 1], [2, 3]]
    k = 5
    # Start at 1, neighbors are 4 (left) and 2 (below)
    # 1 -> 2 (smaller) -> 1 or 3? 1 is smaller
    # Path: 1, 2, 1, 2, 1 or 1, 2, 1, 2, 1
    expected = [1, 2, 1, 2, 1]
    
    flat_grid = grid_to_bytes(grid)
    for i in range(4):
        dut.grid[i].value = flat_grid[i]
    dut.k.value = k
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result = [int(dut.result[i].value) for i in range(10) if int(dut.result[i].value) > 0]
    print(f"Test 4: Expected {expected}, Got {result}")
    if result != expected:
        raise TestFailure(f"Path mismatch: expected {expected}, got {result}")

@cocotb.test()
async def test_minPath_multiple_runs(dut):
    """Test running multiple computations back-to-back"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ([[1,2],[3,4]], 4, [1,2,1,2]),
        ([[2,1],[4,3]], 3, [1,2,1]),
        ([[1,4],[2,3]], 8, [1,2,1,2,1,2,1,2]),
    ]
    
    for grid, k, expected in test_cases:
        flat_grid = grid_to_bytes(grid)
        for i in range(4):
            dut.grid[i].value = flat_grid[i]
        dut.k.value = k
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for _ in range(250):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        result = [int(dut.result[i].value) for i in range(10) if int(dut.result[i].value) > 0]
        print(f"Multi-test: grid={grid}, k={k}, expected={expected}, got={result}")
        if result != expected:
            raise TestFailure(f"Failed for grid={grid}, k={k}: expected {expected}, got {result}")
        
        # Small delay between tests
        await Timer(20, units='ns')
        dut.rst_n.value = 0
        await Timer(20, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

print("Summary: All 5 tests should pass for the 2x2 grid, k<=10 constraint")