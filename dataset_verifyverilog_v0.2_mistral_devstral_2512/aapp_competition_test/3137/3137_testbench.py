import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

# Helper to map directions
# 0: U, 1: R, 2: D, 3: L
dir_map = {'U': 0, 'R': 1, 'D': 2, 'L': 3}
delta = {0: (-1, 0), 1: (0, 1), 2: (1, 0), 3: (0, -1)}

@cocotb.test()
async def test_bacteria_game(dut):
    """Test the bacteria game simulator"""
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # --- Test Case 1: Sample Input 1 ---
    # 3 3 1
    # 2 2
    # 1 1 R
    # 010
    # 000
    # 000
    # Expected output: 2
    
    N, M, K = 3, 3, 1
    trap_row, trap_col = 2, 2
    
    # Bacterium 0
    start_row_0, start_col_0 = 1, 1
    start_dir_0 = dir_map['R']
    grid_0 = [
        [0, 1, 0],
        [0, 0, 0],
        [0, 0, 0]
    ]
    
    # Load inputs
    dut.trap_row.value = trap_row
    dut.trap_col.value = trap_col
    
    # Since array input handling in cocotb can vary, we access internal signals directly
    # This assumes the DUT connects signals to logic properly.
    # For this test, we will manually simulate and verify against expected duration logic
    # or check if the DUT performs the correct number of cycles.
    
    # Let's implement a generic simulation loop in Python to verify the DUT's result
    # The DUT should handle the logic, so we just trigger it.
    
    # We need to load the grid and start positions.
    # Note: Accessing multi-dimensional arrays in Verilog from Python requires careful indexing.
    # dut.grid[0][0][0].value = grid_0[0][0] ... etc.
    
    dut.start_row[0].value = start_row_0
    dut.start_col[0].value = start_col_0
    dut.start_dir[0].value = start_dir_0
    for r in range(N):
        for c in range(M):
            dut.grid[0][r][c].value = grid_0[r][c]
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 1000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            result = int(dut.duration.value)
            dut._log.info(f"Test 1 Result: {result} (Expected: 2)")
            assert result == 2, f"Test 1 failed: got {result}, expected 2"
            break
        if i == timeout - 1:
            assert False, "Test 1 timed out"
            
    # --- Test Case 2: Sample Input 2 ---
    # 3 4 2
    # 2 2
    # 3 4 R ... -> ... -> Expected 7
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    N, M, K = 3, 4, 2
    trap_row, trap_col = 2, 2
    
    dut.trap_row.value = trap_row
    dut.trap_col.value = trap_col
    
    # Bact 0
    dut.start_row[0].value = 3
    dut.start_col[0].value = 4
    dut.start_dir[0].value = dir_map['R']
    grid_0_t2 = [
        [2,3,2,7],
        [6,0,0,9],
        [2,1,1,2]
    ]
    for r in range(N):
        for c in range(M):
            dut.grid[0][r][c].value = grid_0_t2[r][c]
            
    # Bact 1
    dut.start_row[1].value = 3
    dut.start_col[1].value = 2
    dut.start_dir[1].value = dir_map['R']
    grid_1_t2 = [
        [1,3,1,0],
        [2,1,0,1],
        [1,3,0,1]
    ]
    for r in range(N):
        for c in range(M):
            dut.grid[1][r][c].value = grid_1_t2[r][c]
            
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 200
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            result = int(dut.duration.value)
            dut._log.info(f"Test 2 Result: {result} (Expected: 7)")
            assert result == 7, f"Test 2 failed: got {result}, expected 7"
            break
        if i == timeout - 1:
            assert False, "Test 2 timed out"
