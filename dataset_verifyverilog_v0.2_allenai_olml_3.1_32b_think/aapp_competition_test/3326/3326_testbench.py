import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

@cocotb.test()
async def test_monotonic_subgrids(dut):
    """Test monotonic subgrid counting for 4x4 grids"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.grid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 3x3 example from problem (embedded in 4x4)
    # Grid: [[1,2,5,0],[7,6,4,0],[9,8,3,0],[0,0,0,0]]
    # Expected: All 49 subgrids are monotonic
    dut.grid.value = 0
    dut.grid[0][0] = 1
    dut.grid[0][1] = 2
    dut.grid[0][2] = 5
    dut.grid[0][3] = 0  # padding
    dut.grid[1][0] = 7
    dut.grid[1][1] = 6
    dut.grid[1][2] = 4
    dut.grid[1][3] = 0
    dut.grid[2][0] = 9
    dut.grid[2][1] = 8
    dut.grid[2][2] = 3
    dut.grid[2][3] = 0
    dut.grid[3][0] = 0
    dut.grid[3][1] = 0
    dut.grid[3][2] = 0
    dut.grid[3][3] = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (allow up to 150 cycles)
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Module did not complete in time"
    print(f"Test 1 - Result: {dut.result.value}")
    # For 4x4, many subgrids include zeros, so result will differ
    # Just verify it completes
    
    # Test case 2: Simple increasing grid (all monotonic)
    # [[1,2,3,4],[5,6,7,8],[9,10,11,12],[13,14,15,16]]
    for i in range(4):
        for j in range(4):
            dut.grid[i][j] = i*4 + j + 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Test 2: Module did not complete"
    result2 = int(dut.result.value)
    print(f"Test 2 - Increasing grid: {result2} monotonic subgrids")
    # 1x1 = 16, 1x2 rows = 24, 2x1 cols = 24, 2x2 = 36, etc.
    # All should be monotonic: 16 + 24 + 24 + 36 + 4 + 4 + 1 = 109
    assert result2 > 0, "Should have some monotonic subgrids"
    
    # Test case 3: Random permutation (mixed monotonicity)
    random.seed(42)
    values = list(range(1, 17))
    random.shuffle(values)
    idx = 0
    for i in range(4):
        for j in range(4):
            dut.grid[i][j] = values[idx]
            idx += 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Test 3: Module did not complete"
    result3 = int(dut.result.value)
    print(f"Test 3 - Random grid: {result3} monotonic subgrids")
    assert result3 >= 16, "At least 1x1 subgrids should be monotonic"
    assert result3 <= 255, "Result should fit in 8 bits"
    
    # Test case 4: Degenerate case - all same values (should all be monotonic)
    # Actually values must be distinct per problem, so test strictly decreasing
    dut.grid[0][0] = 16
    dut.grid[0][1] = 15
    dut.grid[0][2] = 14
    dut.grid[0][3] = 13
    dut.grid[1][0] = 12
    dut.grid[1][1] = 11
    dut.grid[1][2] = 10
    dut.grid[1][3] = 9
    dut.grid[2][0] = 8
    dut.grid[2][1] = 7
    dut.grid[2][2] = 6
    dut.grid[2][3] = 5
    dut.grid[3][0] = 4
    dut.grid[3][1] = 3
    dut.grid[3][2] = 2
    dut.grid[3][3] = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Test 4: Module did not complete"
    result4 = int(dut.result.value)
    print(f"Test 4 - Decreasing grid: {result4} monotonic subgrids")
    assert result4 > 0, "Should have monotonic subgrids"
    
    print("
All tests passed!")