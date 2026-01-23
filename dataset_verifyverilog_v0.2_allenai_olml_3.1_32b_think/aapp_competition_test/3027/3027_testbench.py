import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_bureaucrat_stamp(dut):
    # Create a clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.paper_grid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 4x8 pattern (scaled to 8x8)
    # Original: ..#..#..
    #          .######.
    #          .######.
    #          ..#..#..
    # Expected: 8
    grid1 = [[0,0,1,0,0,1,0,0],
             [0,1,1,1,1,1,1,0],
             [0,1,1,1,1,1,1,0],
             [0,0,1,0,0,1,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0]]
    
    # Convert to single value for Verilog input
    grid_val = 0
    for i in range(8):
        for j in range(8):
            if grid1[i][j]:
                grid_val |= (1 << (i*8 + j))
    
    dut.paper_grid.value = grid_val
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for computation to complete (max 10,000 cycles)
    cycles = 0
    while not dut.done.value and cycles < 10000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if not dut.done.value:
        raise TestFailure("Test case 1: Did not complete within 10000 cycles")
    
    result1 = int(dut.min_nubs.value)
    print(f"Test case 1: Expected 8, Got {result1}")
    assert result1 == 8, f"Test case 1 failed: expected 8, got {result1}"
    
    await RisingEdge(dut.clk)
    
    # Test case 2: 3x3 pattern with single '#', scaled to 8x8
    # Expected: 1
    grid2 = [[0,0,0,0,0,0,0,0],
             [0,0,0,1,0,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0]]
    
    grid_val = 0
    for i in range(8):
        for j in range(8):
            if grid2[i][j]:
                grid_val |= (1 << (i*8 + j))
    
    dut.paper_grid.value = grid_val
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 10000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if not dut.done.value:
        raise TestFailure("Test case 2: Did not complete within 10000 cycles")
    
    result2 = int(dut.min_nubs.value)
    print(f"Test case 2: Expected 1, Got {result2}")
    assert result2 == 1, f"Test case 2 failed: expected 1, got {result2}"
    
    await RisingEdge(dut.clk)
    
    # Test case 3: 2x6 pattern, scaled to 8x8
    # .#####
    # #####.
    # Expected: 5
    grid3 = [[0,1,1,1,1,1,0,0],
             [1,1,1,1,1,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0]]
    
    grid_val = 0
    for i in range(8):
        for j in range(8):
            if grid3[i][j]:
                grid_val |= (1 << (i*8 + j))
    
    dut.paper_grid.value = grid_val
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 10000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if not dut.done.value:
        raise TestFailure("Test case 3: Did not complete within 10000 cycles")
    
    result3 = int(dut.min_nubs.value)
    print(f"Test case 3: Expected 5, Got {result3}")
    assert result3 == 5, f"Test case 3 failed: expected 5, got {result3}"
    
    await RisingEdge(dut.clk)
    
    # Test case 4: 2x5 pattern, scaled to 8x8
    # .#.#.
    # #.#.#
    # Expected: 3
    grid4 = [[0,1,0,1,0,0,0,0],
             [1,0,1,0,1,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0],
             [0,0,0,0,0,0,0,0]]
    
    grid_val = 0
    for i in range(8):
        for j in range(8):
            if grid4[i][j]:
                grid_val |= (1 << (i*8 + j))
    
    dut.paper_grid.value = grid_val
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 10000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if not dut.done.value:
        raise TestFailure("Test case 4: Did not complete within 10000 cycles")
    
    result4 = int(dut.min_nubs.value)
    print(f"Test case 4: Expected 3, Got {result4}")
    assert result4 == 3, f"Test case 4 failed: expected 3, got {result4}"
    
    print("All tests passed!")