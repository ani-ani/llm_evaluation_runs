import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_stamp_verification(dut):
    """Test 4x4 grid stamp verification"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.row_idx.value = 0
    dut.col_idx.value = 0
    dut.target_color.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case 1: YES - All white (easy, no stamps needed)
    dut._log.info("Test 1: All white grid")
    grid1 = [[0,0,0,0], [0,0,0,0], [0,0,0,0], [0,0,0,0]]  # All white
    for r in range(4):
        for c in range(4):
            dut.row_idx.value = r
            dut.col_idx.value = c
            dut.target_color.value = grid1[r][c]
            await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # Wait for completion
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    assert dut.result.value == 1, f"Test 1 failed: expected YES, got {dut.result.value}"
    
    # Test case 2: YES - Single 3x3 stamp at (0,0) with red
    dut._log.info("Test 2: Single stamp at (0,0) red")
    grid2 = [[0,0,0,0], [0,0,0,0], [0,0,0,0], [0,0,0,0]]  # Start from white
    # Apply red stamp at (0,0): affects rows 0-2, cols 0-2
    for r in range(3):
        for c in range(3):
            grid2[r][c] = 1  # Red
    # Load grid
    for r in range(4):
        for c in range(4):
            dut.row_idx.value = r
            dut.col_idx.value = c
            dut.target_color.value = grid2[r][c]
            await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    assert dut.result.value == 1, f"Test 2 failed: expected YES, got {dut.result.value}"
    
    # Test case 3: YES - Two stamps creating pattern
    dut._log.info("Test 3: Two stamps overlapping")
    grid3 = [[0,0,0,0], [0,0,0,0], [0,0,0,0], [0,0,0,0]]
    # Stamp at (0,0) red
    for r in range(3):
        for c in range(3):
            grid3[r][c] = 1
    # Stamp at (1,1) green (overwrites center)
    for r in range(1,4):
        for c in range(1,4):
            grid3[r][c] = 2
    # Load
    for r in range(4):
        for c in range(4):
            dut.row_idx.value = r
            dut.col_idx.value = c
            dut.target_color.value = grid3[r][c]
            await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    assert dut.result.value == 1, f"Test 3 failed: expected YES, got {dut.result.value}"
    
    # Test case 4: NO - Impossible pattern (alternating corners)
    dut._log.info("Test 4: Impossible alternating corners")
    grid4 = [[1,0,0,1], [0,0,0,0], [0,0,0,0], [1,0,0,1]]  # Red corners
    for r in range(4):
        for c in range(4):
            dut.row_idx.value = r
            dut.col_idx.value = c
            dut.target_color.value = grid4[r][c]
            await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    assert dut.result.value == 0, f"Test 4 failed: expected NO, got {dut.result.value}"
    
    # Test case 5: YES - Full coverage with blue
    dut._log.info("Test 5: All blue via multiple stamps")
    grid5 = [[3,3,3,3], [3,3,3,3], [3,3,3,3], [3,3,3,3]]  # All blue
    for r in range(4):
        for c in range(4):
            dut.row_idx.value = r
            dut.col_idx.value = c
            dut.target_color.value = grid5[r][c]
            await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    assert dut.result.value == 1, f"Test 5 failed: expected YES, got {dut.result.value}"
    
    dut._log.info("All tests completed!")
    print(f"Tests: 5/5 passed")