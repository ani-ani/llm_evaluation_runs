import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ReadOnly
from cocotb.result import TestFailure, TestSuccess
import random

# Helper to check symmetry in Python for verification
def check_symmetry_python(grid, H, W):
    # Check if there exists a row permutation and column permutation such that
    # grid[r_perm[i]][c_perm[j]] == grid[r_perm[H-1-i]][c_perm[W-1-j]]
    # This is hard to verify generally, so we will rely on the testbench to provide
    # specific known cases.
    # However, we can verify the logic of the module by checking if the Python
    # code finds a solution that matches the module's output.
    pass

@cocotb.test()
def test_grid_symmetry_basic(dut):
    """Test basic symmetric cases"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: 2x3 Grid "arc", "rac" -> YES
    # Rows: 0=arc, 1=rac
    # ASCII: 'a'=97, 'r'=114, 'c'=99
    # 'r'=114, 'a'=97, 'c'=99
    H, W = 2, 3
    grid = [
        [97, 114, 99], # arc
        [114, 97, 99]  # rac
    ]
    # Flatten: row 0, then row 1
    flat = []
    for r in range(H):
        flat.extend(grid[r])
        flat.extend([0]*(12 - W)) # Padding to 12 columns
    for _ in range(6 - H):
        flat.extend([0]*12) # Padding rows
    
    dut.H_in.value = H
    dut.W_in.value = W
    for i in range(72):
        dut.grid_flat[i].value = flat[i]
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if not dut.done.value:
        raise TestFailure("Test Case 1: Timeout waiting for done")
    
    if not dut.result.value:
        raise TestFailure(f"Test Case 1: Expected YES (1), got {dut.result.value}")
    dut._log.info("Test Case 1 (2x3 arc/rac) passed")
    
    # Test Case 2: 2x2 Symmetric
    # ab
    # ba
    # ASCII: 'a'=97, 'b'=98
    H, W = 2, 2
    grid = [
        [97, 98],
        [98, 97]
    ]
    flat = []
    for r in range(H):
        flat.extend(grid[r])
        flat.extend([0]*(12 - W))
    for _ in range(6 - H):
        flat.extend([0]*12)
    
    dut.H_in.value = H
    dut.W_in.value = W
    for i in range(72):
        dut.grid_flat[i].value = flat[i]
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if not dut.result.value:
        raise TestFailure(f"Test Case 2: Expected YES (1), got {dut.result.value}")
    dut._log.info("Test Case 2 (2x2 ab/ba) passed")

    # Test Case 3: 2x2 Asymmetric
    # ab
    # ab
    H, W = 2, 2
    grid = [
        [97, 98],
        [97, 98]
    ]
    flat = []
    for r in range(H):
        flat.extend(grid[r])
        flat.extend([0]*(12 - W))
    for _ in range(6 - H):
        flat.extend([0]*12)
        
    dut.H_in.value = H
    dut.W_in.value = W
    for i in range(72):
        dut.grid_flat[i].value = flat[i]
        
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if dut.result.value:
        raise TestFailure(f"Test Case 3: Expected NO (0), got {dut.result.value}")
    dut._log.info("Test Case 3 (2x2 ab/ab) passed")

    # Test Case 4: 3x3 Center Symmetric
    # aaa
    # aba
    # aaa
    H, W = 3, 3
    grid = [
        [97, 97, 97],
        [97, 98, 97],
        [97, 97, 97]
    ]
    flat = []
    for r in range(H):
        flat.extend(grid[r])
        flat.extend([0]*(12 - W))
    for _ in range(6 - H):
        flat.extend([0]*12)
        
    dut.H_in.value = H
    dut.W_in.value = W
    for i in range(72):
        dut.grid_flat[i].value = flat[i]
        
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if not dut.result.value:
        raise TestFailure(f"Test Case 4: Expected YES (1), got {dut.result.value}")
    dut._log.info("Test Case 4 (3x3 center) passed")

    # Test Case 5: 1x1 Single char
    # a
    H, W = 1, 1
    grid = [[97]]
    flat = []
    for r in range(H):
        flat.extend(grid[r])
        flat.extend([0]*(12 - W))
    for _ in range(6 - H):
        flat.extend([0]*12)
        
    dut.H_in.value = H
    dut.W_in.value = W
    for i in range(72):
        dut.grid_flat[i].value = flat[i]
        
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if not dut.result.value:
        raise TestFailure(f"Test Case 5: Expected YES (1), got {dut.result.value}")
    dut._log.info("Test Case 5 (1x1) passed")
