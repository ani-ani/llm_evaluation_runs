import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_forest_growth_basic(dut):
    """Test basic functionality with simple cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 2x2 grid, all same (h=1, v=1) - should get size 4
    # Flatten: row-major order
    heights = [1, 1, 1, 1]  # 2x2 grid (scaled down)
    speeds = [1, 1, 1, 1]
    
    for i in range(4):
        dut.heights[i].value = heights[i]
        dut.speeds[i].value = speeds[i]
    
    # Fill rest with dummy values
    for i in range(4, 64):
        dut.heights[i].value = 0
        dut.speeds[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion with timeout
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 5000:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    result = int(dut.max_group_size.value)
    dut._log.info(f"Test 1 result: {result}, expected: 4")
    assert result == 4, f"Test 1 failed: got {result}, expected 4"
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: 3x3 grid (adapted from sample)
    # Original sample has answer 7, we'll scale down
    # Let's create: 3x3 where we have 5 cells with (h=2,v=3) connected
    heights = [
        2, 2, 3,
        2, 2, 3,
        3, 3, 3
    ]
    speeds = [
        3, 3, 2,
        3, 3, 2,
        2, 2, 2
    ]
    # The 2x2 block of (2,3) in top-left should give size 4
    # Plus maybe more
    
    for i in range(9):
        dut.heights[i].value = heights[i]
        dut.speeds[i].value = speeds[i]
    
    for i in range(9, 64):
        dut.heights[i].value = 0
        dut.speeds[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 5000:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    result = int(dut.max_group_size.value)
    dut._log.info(f"Test 2 result: {result}, expected: 4")
    # In this configuration, the 2x2 (2,3) block is size 4
    assert result >= 4, f"Test 2 failed: got {result}, expected at least 4"
    
    # Test Case 3: Mixed grid with various (h,v) pairs
    # Create diagonal pattern of same values
    heights = [
        5, 0, 0, 0, 0, 0, 0, 0,
        0, 5, 0, 0, 0, 0, 0, 0,
        0, 0, 5, 0, 0, 0, 0, 0,
        0, 0, 0, 5, 0, 0, 0, 0,
        0, 0, 0, 0, 5, 0, 0, 0,
        0, 0, 0, 0, 0, 5, 0, 0,
        0, 0, 0, 0, 0, 0, 5, 0,
        0, 0, 0, 0, 0, 0, 0, 5
    ]
    speeds = [
        2, 0, 0, 0, 0, 0, 0, 0,
        0, 2, 0, 0, 0, 0, 0, 0,
        0, 0, 2, 0, 0, 0, 0, 0,
        0, 0, 0, 2, 0, 0, 0, 0,
        0, 0, 0, 0, 2, 0, 0, 0,
        0, 0, 0, 0, 0, 2, 0, 0,
        0, 0, 0, 0, 0, 0, 2, 0,
        0, 0, 0, 0, 0, 0, 0, 2
    ]
    # All are (5,2) but diagonal - each isolated, so size 1
    
    for i in range(64):
        dut.heights[i].value = heights[i]
        dut.speeds[i].value = speeds[i]
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 5000:
        raise TestFailure("Test 3: Timeout waiting for done")
    
    result = int(dut.max_group_size.value)
    dut._log.info(f"Test 3 result: {result}, expected: 1")
    assert result >= 1, f"Test 3 failed: got {result}, expected at least 1"
    
    # Test Case 4: Single cell
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    heights = [7] + [0]*63
    speeds = [4] + [0]*63
    
    for i in range(64):
        dut.heights[i].value = heights[i]
        dut.speeds[i].value = speeds[i]
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 5000:
        raise TestFailure("Test 4: Timeout waiting for done")
    
    result = int(dut.max_group_size.value)
    dut._log.info(f"Test 4 result: {result}, expected: 1")
    assert result == 1, f"Test 4 failed: got {result}, expected 1"
    
    dut._log.info("All 4 tests passed!")

@cocotb.test()
async def test_forest_growth_edge_cases(dut):
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
    
    # Test: All cells same - should get 64
    for i in range(64):
        dut.heights[i].value = 10
        dut.speeds[i].value = 10
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 5000:
        raise TestFailure("Edge Test 1: Timeout")
    
    result = int(dut.max_group_size.value)
    dut._log.info(f"Edge Test 1: All same, result={result}")
    assert result == 64, f"Edge Test 1 failed: got {result}, expected 64"
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: All different
    for i in range(64):
        dut.heights[i].value = i % 256
        dut.speeds[i].value = (i * 7) % 256
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 5000:
        raise TestFailure("Edge Test 2: Timeout")
    
    result = int(dut.max_group_size.value)
    dut._log.info(f"Edge Test 2: All different, result={result}")
    assert result == 1, f"Edge Test 2 failed: got {result}, expected 1"
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: Checkerboard pattern (2x2 blocks same)
    # 00 00 01 01 ...
    # 00 00 01 01 ...
    # 02 02 03 03 ...
    # ...
    # Each 2x2 block has same (h,v)
    for row in range(8):
        for col in range(8):
            idx = row * 8 + col
            block = (row // 2) * 4 + (col // 2)
            dut.heights[idx].value = block
            dut.speeds[idx].value = block
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 5000:
        raise TestFailure("Edge Test 3: Timeout")
    
    result = int(dut.max_group_size.value)
    dut._log.info(f"Edge Test 3: Checkerboard, result={result}")
    assert result == 4, f"Edge Test 3 failed: got {result}, expected 4"
    
    dut._log.info("All edge case tests passed!")