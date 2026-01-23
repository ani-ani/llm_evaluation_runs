import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

def calculate_optimal(grid_2d, K):
    """Calculate optimal minimum sum for 4x4 grid"""
    # Generate all possible dominoes
    dominoes = []
    # Horizontal dominoes
    for r in range(4):
        for c in range(3):
            idx1 = r * 4 + c
            idx2 = r * 4 + c + 1
            dominoes.append(((idx1, idx2), grid_2d[r][c] + grid_2d[r][c+1]))
    # Vertical dominoes
    for r in range(3):
        for c in range(4):
            idx1 = r * 4 + c
            idx2 = (r + 1) * 4 + c
            dominoes.append(((idx1, idx2), grid_2d[r][c] + grid_2d[r+1][c]))
    
    total_sum = sum(sum(row) for row in grid_2d)
    
    best_covered = 0
    # Try all combinations of K dominoes
    def find_best(remaining_k, start_idx, used_mask, covered_sum):
        nonlocal best_covered
        if remaining_k == 0:
            if covered_sum > best_covered:
                best_covered = covered_sum
            return
        if start_idx >= len(dominoes):
            return
        # Try placing this domino if possible
        (c1, c2), value = dominoes[start_idx]
        if not (used_mask & (1 << c1)) and not (used_mask & (1 << c2)):
            find_best(remaining_k - 1, start_idx + 1, used_mask | (1 << c1) | (1 << c2), covered_sum + value)
        # Skip this domino
        find_best(remaining_k, start_idx + 1, used_mask, covered_sum)
    
    find_best(K, 0, 0, 0)
    return total_sum - best_covered

@cocotb.test()
async def test_domino_solver(dut):
    """Test domino solver with multiple test cases"""
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.K.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 3x3 example from problem (scaled to 4x4)
    # Original: 2 7 6 / 9 5 1 / 4 3 8, K=1
    # Adapted to 4x4: add 0s in last row/col
    grid1 = [
        [2, 7, 6, 0],
        [9, 5, 1, 0],
        [4, 3, 8, 0],
        [0, 0, 0, 0]
    ]
    expected1 = 31  # Total=45, best domino covers (9,5) or (7,6) = 14, 45-14=31
    
    # Test Case 2: 4x4 example from problem, K=2
    grid2 = [
        [1, 2, 4, 0],
        [4, 0, 5, 4],
        [0, 3, 5, 1],
        [1, 0, 4, 1]
    ]
    expected2 = 17
    
    # Test Case 3: All zeros, K=1
    grid3 = [[0]*4 for _ in range(4)]
    expected3 = 0
    
    # Test Case 4: High values, K=3
    grid4 = [
        [255, 255, 255, 255],
        [255, 255, 255, 255],
        [255, 255, 255, 255],
        [255, 255, 255, 255]
    ]
    # Optimal: 3 dominoes covering 6 cells = 6*255 = 1530, total=4080, result=2550
    expected4 = 2550
    
    # Test Case 5: K=3 with specific pattern
    grid5 = [
        [10, 10, 1, 1],
        [10, 10, 1, 1],
        [1, 1, 10, 10],
        [1, 1, 10, 10]
    ]
    # Should cover the 10 clusters, total=96, best cover 3*20=60, result=36
    expected5 = 36
    
    test_cases = [
        (grid1, 1, expected1),
        (grid2, 2, expected2),
        (grid3, 1, expected3),
        (grid4, 3, expected4),
        (grid5, 3, expected5),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (grid, k_val, expected) in enumerate(test_cases):
        # Load grid
        for r in range(4):
            for c in range(4):
                idx = r * 4 + c
                dut.grid[idx].value = grid[r][c]
        
        dut.K.value = k_val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 500:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 500:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done")
        
        result = int(dut.min_sum.value)
        if result == expected:
            passed += 1
            dut._log.info(f"Test {i+1} PASSED: K={k_val}, result={result}")
        else:
            dut._log.error(f"Test {i+1} FAILED: K={k_val}, expected={expected}, got={result}")
        
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")