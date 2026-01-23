import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def solve_maze_ref(n, m, r, c, L, R, grid):
    """Reference Python implementation for verification"""
    dist = [[float('inf')] * m for _ in range(n)]
    dist[r][c] = 0
    q = [(r, c)]
    head = 0
    
    # This uses the logic from the first python example in the prompt
    while head < len(q):
        x, y = q[head]
        head += 1
        d = dist[x][y]
        
        # Down
        if x + 1 < n and dist[x+1][y] > d and grid[x+1][y] == '.':
            dist[x+1][y] = d
            q.append((x+1, y))
        # Up
        if x - 1 >= 0 and dist[x-1][y] > d and grid[x-1][y] == '.':
            dist[x-1][y] = d
            q.append((x-1, y))
        # Right
        if y + 1 < m and dist[x][y+1] > d and grid[x][y+1] == '.':
            dist[x][y+1] = d + 1
            q.append((x, y+1))
        # Left
        if y - 1 >= 0 and dist[x][y-1] > d and grid[x][y-1] == '.':
            dist[x][y-1] = d + 1
            q.append((x, y-1))
            
    ans = 0
    for i in range(n):
        for j in range(m):
            if dist[i][j] < float('inf'):
                # dist is total cost (up/down cost 0, left/right cost 1 in modified logic?)
                # Wait, the first python code uses 'd' as distance in up/down moves?
                # Let's use the logic: d is number of left+right moves?
                # Actually, simpler logic from other solutions:
                # Calculate required left and right moves based on horizontal displacement.
                # Total steps = dist[i][j].
                # Let x = dist[i][j].
                # Let dx = j - c.
                # Right moves needed = (x + dx) / 2
                # Left moves needed = (x - dx) / 2
                x = dist[i][j]
                dx = j - c
                right = (x + dx) // 2
                left = (x - dx) // 2
                if right <= R and left <= L:
                    ans += 1
    return ans

@cocotb.test()
async def test_maze_solver(dut):
    """Test the maze solver module"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.grid_data.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases (Scaled down to fit 8x8 grid)
    # We will map the provided inputs to the module's interface
    # Module: max 8x8 grid (indices 0-7)
    # Input test case 0: 4x5 grid, start (2,1) [0-indexed], L=1, R=2
    test_cases = [
        {
            'n': 4, 'm': 5, 'r': 2, 'c': 1, 'L': 1, 'R': 2,
            'grid': [
                ".....",
                ".***.",
                "...**",
                "*...."
            ],
            'expected': 10
        },
        {
            'n': 4, 'm': 4, 'r': 1, 'c': 1, 'L': 0, 'R': 1,
            'grid': [
                "....",
                "..*.",
                "....",
                "...."
            ],
            'expected': 7
        },
        {
            'n': 1, 'm': 1, 'r': 0, 'c': 0, 'L': 0, 'R': 0,
            'grid': ["."],
            'expected': 1
        },
        {
            'n': 1, 'm': 1, 'r': 0, 'c': 0, 'L': 31, 'R': 42,
            'grid': ["."],
            'expected': 1
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        print(f"Running Test Case {i+1}/{total}")
        
        n, m = tc['n'], tc['m']
        r, c = tc['r'], tc['c']
        L, R = tc['L'], tc['R']
        expected = tc['expected']
        
        # Configure DUT inputs
        dut.grid_size_x.value = n
        dut.grid_size_y.value = m
        dut.start_x.value = r
        dut.start_y.value = c
        dut.max_left.value = L
        dut.max_right.value = R
        
        # Flatten grid into 64-bit vector (8x8)
        # Index = row * 8 + col
        grid_flat = 0
        for row_idx in range(8):
            for col_idx in range(8):
                bit_pos = row_idx * 8 + col_idx
                if row_idx < n and col_idx < m:
                    if tc['grid'][row_idx][col_idx] == '.':
                        grid_flat |= (1 << bit_pos)
                # If out of bounds or obstacle, bit stays 0 (obstacle)
        dut.grid_data.value = grid_flat
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 1000:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 1000:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
            
        # Check result
        actual = int(dut.result.value)
        
        # Handle cases where the problem constraints (L/R) are very large (like 10^9) but grid is small.
        # If L/R are huge, all reachable cells should be counted.
        # My Python reference scales L/R correctly.
        
        # Debug print
        print(f"  Inputs: n={n}, m={m}, start=({r},{c}), L={L}, R={R}")
        print(f"  Expected: {expected}, Actual: {actual}")
        
        if actual == expected:
            passed += 1
        else:
            print(f"  FAILED: Expected {expected}, got {actual}")
            
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, "Some tests failed"
