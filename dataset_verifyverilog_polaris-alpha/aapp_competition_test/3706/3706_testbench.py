import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_grid_solver(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await Timer(15, units='ns')
    
    # Test Case 1: Solvable grid (output 4 moves)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    grid1 = [[2,2,2,0], [0,0,0,0], [1,1,1,0], [0,0,0,0]]  # Adapted 3x5 case
    for i in range(4):
        for j in range(4):
            dut.grid[i][j].value = grid1[i][j] if i < 3 and j < 3 else 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await Timer(200, units='ns')  # Wait for computation
    if dut.error.value != 0 or dut.move_count.value != 4:
        raise TestFailure("Test 1 failed: Expected move_count=4, error=0")
    
    # Test Case 2: Impossible grid (error)
    grid2 = [[0,0,0],[0,1,0],[0,0,0],[0,0,0]]
    for i in range(4):
        for j in range(4):
            dut.grid[i][j].value = grid2[i][j] if i < 3 and j < 3 else 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await Timer(200, units='ns')
    if dut.error.value != 1:
        raise TestFailure("Test 2 failed: Expected error=1")
    
    # Test Case 3: All ones (output 4 moves - row approach)
    grid3 = [[1,1,1,1],[1,1,1,1],[1,1,1,1],[1,1,1,1]]
    for i in range(4):
        for j in range(4):
            dut.grid[i][j].value = grid3[i][j]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await Timer(200, units='ns')
    if dut.error.value != 0 or dut.move_count.value != 4:
        raise TestFailure("Test 3 failed: Expected move_count=4")
    
    dut._log.info("3/3 tests passed")