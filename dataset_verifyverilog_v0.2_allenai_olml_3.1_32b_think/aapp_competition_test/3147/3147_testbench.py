import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def check_180_symmetry(matrix, row_start, col_start, size):
    """Check if square submatrix of given size at position is 180-degree symmetric"""
    for r in range(size):
        for c in range(size):
            val1 = matrix[row_start + r][col_start + c]
            val2 = matrix[row_start + size - 1 - r][col_start + size - 1 - c]
            if val1 != val2:
                return False
    return True

def find_largest_killer(matrix, max_dim=16):
    """Find largest square killer in matrix"""
    rows = len(matrix)
    cols = len(matrix[0])
    max_size = 0
    
    for size in range(min(rows, cols), 1, -1):  # Check from largest to smallest
        for i in range(rows - size + 1):
            for j in range(cols - size + 1):
                if check_180_symmetry(matrix, i, j, size):
                    if size > max_size:
                        max_size = size
        if max_size > 0:
            break
    
    return max_size

@cocotb.test()
async def test_square_killer_finder(dut):
    """Test square killer finder with multiple cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled from original)
    test_cases = [
        # Case 1: 3x6 matrix with killers of size 2, 2, 3 -> max 3
        [
            [1,0,1,0,1,0],
            [1,1,1,0,0,1],
            [1,0,1,0,0,1]
        ],
        # Case 2: 4x5 matrix -> max 3
        [
            [1,0,0,1,0],
            [0,1,0,1,0],
            [1,0,1,0,1],
            [0,1,0,0,1]
        ],
        # Case 3: 3x3 matrix -> no killer
        [
            [1,0,1],
            [1,1,1],
            [1,0,0]
        ],
        # Additional edge case: 2x2 symmetric matrix
        [
            [1,1],
            [1,1]
        ],
        # Additional case: all zeros 4x4
        [
            [0,0,0,0],
            [0,0,0,0],
            [0,0,0,0],
            [0,0,0,0]
        ]
    ]
    
    expected_results = [3, 3, 0, 2, 4]
    
    for idx, (matrix, expected) in enumerate(zip(test_cases, expected_results)):
        print(f"
Test case {idx + 1}: {len(matrix)}x{len(matrix[0])} matrix")
        
        # Pad matrix to 16x16 with zeros
        padded_matrix = [[0] * 16 for _ in range(16)]
        for r in range(len(matrix)):
            for c in range(len(matrix[0])):
                padded_matrix[r][c] = matrix[r][c]
        
        # Load matrix into DUT
        for r in range(16):
            row_val = 0
            for c in range(16):
                row_val |= (padded_matrix[r][c] << c)
            dut.matrix_row[r].value = row_val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 5000
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Test {idx + 1}: Timeout waiting for done signal")
        
        # Read result
        result = int(dut.max_size.value)
        print(f"  Expected: {expected}, Got: {result}")
        
        if result != expected:
            raise TestFailure(f"Test {idx + 1}: Expected {expected}, got {result}")
    
    print("
All tests passed!")
    print(f"Tests: {len(test_cases)}/{len(test_cases)} passed")
