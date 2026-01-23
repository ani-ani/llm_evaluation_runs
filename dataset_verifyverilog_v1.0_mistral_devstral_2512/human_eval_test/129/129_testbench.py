import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

# Helper function to check if value is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to pack grid into individual signals
def set_grid(dut, grid):
    """Set 4x4 grid values to module inputs"""
    for row in range(4):
        for col in range(4):
            signal_name = f'grid_{row}_{col}'
            signal = getattr(dut, signal_name)
            signal.value = grid[row][col]

# Helper to read path from outputs
def read_path(dut, k):
    """Read path from module outputs"""
    path = []
    for i in range(k):
        signal_name = f'path_{i}'
        signal = getattr(dut, signal_name)
        if not is_value_defined(signal.value):
            raise TestFailure(f"Path index {i} is undefined")
        path.append(int(signal.value))
    return path

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_min_path_basic(dut):
    """Test basic functionality with simple cases"""
    
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    set_grid(dut, [[0]*4 for _ in range(4)])
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 3x3 grid example adapted to 4x4 with 1,2,3 in first row
    # Grid: [[1,2,3,0], [4,5,6,0], [7,8,9,0], [0,0,0,0]]
    # But we must use values 1-16. Let's use 1,2,3,4,5,6,7,8,9 and fill rest with 10-16
    grid1 = [
        [1, 2, 3, 10],
        [4, 5, 6, 11],
        [7, 8, 9, 12],
        [13, 14, 15, 16]
    ]
    k1 = 3
    
    set_grid(dut, grid1)
    dut.k.value = k1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (with timeout)
    for cycle in range(50):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    path1 = read_path(dut, k1)
    expected1 = [1, 2, 1]
    
    if path1 != expected1:
        raise TestFailure(f"Test 1: Expected {expected1}, got {path1}")
    
    dut._log.info(f"Test 1 passed: {path1}")
    await RisingEdge(dut.clk)
    
    # Test Case 2: k=1, should return [1]
    grid2 = [
        [5, 9, 3, 10],
        [4, 1, 6, 11],
        [7, 8, 2, 12],
        [13, 14, 15, 16]
    ]
    k2 = 1
    
    set_grid(dut, grid2)
    dut.k.value = k2
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for cycle in range(50):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    path2 = read_path(dut, k2)
    expected2 = [1]
    
    if path2 != expected2:
        raise TestFailure(f"Test 2: Expected {expected2}, got {path2}")
    
    dut._log.info(f"Test 2 passed: {path2}")
    await RisingEdge(dut.clk)
    
    # Test Case 3: Larger k value
    # Grid with 1 at (0,0), pattern 1,2,1,2...
    grid3 = [
        [1, 2, 13, 14],
        [3, 4, 15, 16],
        [5, 6, 7, 8],
        [9, 10, 11, 12]
    ]
    k3 = 4
    
    set_grid(dut, grid3)
    dut.k.value = k3
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for cycle in range(50):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure("Test 3: Timeout waiting for done")
    
    path3 = read_path(dut, k3)
    expected3 = [1, 2, 1, 2]
    
    if path3 != expected3:
        raise TestFailure(f"Test 3: Expected {expected3}, got {path3}")
    
    dut._log.info(f"Test 3 passed: {path3}")
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_min_path_advanced(dut):
    """Test more complex cases"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 4: Grid with 1 and 10 adjacent (from example)
    # Adapted: [[6,4,13,10], [5,7,12,1], [3,16,11,15], [8,14,9,2]]
    # 1 at (1,3), 10 at (0,3). Pattern: 1,10,1,10...
    # k=7: [1,10,1,10,1,10,1]
    grid4 = [
        [6, 4, 13, 10],
        [5, 7, 12, 1],
        [3, 16, 11, 15],
        [8, 14, 9, 2]
    ]
    k4 = 7
    
    set_grid(dut, grid4)
    dut.k.value = k4
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for cycle in range(80):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure("Test 4: Timeout waiting for done")
    
    path4 = read_path(dut, k4)
    expected4 = [1, 10, 1, 10, 1, 10, 1]
    
    if path4 != expected4:
        raise TestFailure(f"Test 4: Expected {expected4}, got {path4}")
    
    dut._log.info(f"Test 4 passed: {path4}")
    await RisingEdge(dut.clk)
    
    # Test Case 5: Diagonal 1s pattern (from example)
    # Grid with 1 at (1,2), neighbors include 6, pattern: 1,6,1,6...
    grid5 = [
        [11, 8, 7, 2],
        [5, 16, 1, 4],
        [9, 3, 15, 6],
        [12, 13, 10, 14]
    ]
    k5 = 5
    
    set_grid(dut, grid5)
    dut.k.value = k5
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for cycle in range(80):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure("Test 5: Timeout waiting for done")
    
    path5 = read_path(dut, k5)
    expected5 = [1, 6, 1, 6, 1]
    
    if path5 != expected5:
        raise TestFailure(f"Test 5: Expected {expected5}, got {path5}")
    
    dut._log.info(f"Test 5 passed: {path5}")
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_min_path_edge_cases(dut):
    """Test edge cases"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 6: 2x2 pattern with larger k (k=10)
    # Grid: [[1,2], [3,4]] padded to 4x4
    grid6 = [
        [1, 2, 13, 14],
        [3, 4, 15, 16],
        [5, 6, 7, 8],
        [9, 10, 11, 12]
    ]
    k6 = 10
    
    set_grid(dut, grid6)
    dut.k.value = k6
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for cycle in range(120):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure("Test 6: Timeout waiting for done")
    
    path6 = read_path(dut, k6)
    expected6 = [1, 2, 1, 2, 1, 2, 1, 2, 1, 2]
    
    if path6 != expected6:
        raise TestFailure(f"Test 6: Expected {expected6}, got {path6}")
    
    dut._log.info(f"Test 6 passed: {path6}")
    await RisingEdge(dut.clk)
    
    # Test Case 7: Check pattern with 1 and 3
    # Grid: [[1,3], [3,2]] -> 1,3,1,3 pattern
    grid7 = [
        [1, 3, 13, 14],
        [3, 2, 15, 16],
        [4, 5, 6, 7],
        [8, 9, 10, 11]
    ]
    k7 = 10
    
    set_grid(dut, grid7)
    dut.k.value = k7
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for cycle in range(120):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure("Test 7: Timeout waiting for done")
    
    path7 = read_path(dut, k7)
    expected7 = [1, 3, 1, 3, 1, 3, 1, 3, 1, 3]
    
    if path7 != expected7:
        raise TestFailure(f"Test 7: Expected {expected7}, got {path7}")
    
    dut._log.info(f"Test 7 passed: {path7}")
    await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info("All tests passed: 7/7")
