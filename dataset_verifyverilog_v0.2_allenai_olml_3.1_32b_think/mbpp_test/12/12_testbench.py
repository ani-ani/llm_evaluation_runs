import cocotb
from cocotb.triggers import Timer
import random

# Helper function to compute row sum
def compute_row_sum(row):
    return sum(row)

# Helper function to sort matrix by row sum
def sort_matrix_python(matrix):
    return sorted(matrix, key=sum)

# Helper to convert Python matrix to Verilog format (flattened)
def matrix_to_verilog(matrix):
    # Flatten the 3x3 matrix for Verilog input
    flat = []
    for row in matrix:
        for elem in row:
            # Handle negative numbers by converting to 8-bit unsigned
            val = elem & 0xFF
            flat.append(val)
    return flat

# Helper to convert Verilog output back to Python matrix
def verilog_to_matrix(flat_output):
    matrix = []
    for i in range(3):
        row = []
        for j in range(3):
            idx = i * 3 + j
            val = flat_output[idx]
            # Sign extend if needed (assuming 8-bit signed)
            if val > 127:
                val = val - 256
            row.append(val)
        matrix.append(row)
    return matrix

@cocotb.test()
async def test_matrix_sort_by_row_sum(dut):
    """Test matrix sorting by row sum"""
    
    # Test cases from problem
    test_cases = [
        ([[1, 2, 3], [2, 4, 5], [1, 1, 1]], [[1, 1, 1], [1, 2, 3], [2, 4, 5]]),
        ([[1, 2, 3], [-2, 4, -5], [1, -1, 1]], [[-2, 4, -5], [1, -1, 1], [1, 2, 3]]),
        ([[5, 8, 9], [6, 4, 3], [2, 1, 4]], [[2, 1, 4], [6, 4, 3], [5, 8, 9]]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_matrix, expected_matrix) in enumerate(test_cases):
        print(f"
Test {i+1}: Input={input_matrix}")
        
        # Convert input to Verilog format
        flat_input = matrix_to_verilog(input_matrix)
        
        # Assign to DUT
        for row in range(3):
            for col in range(3):
                idx = row * 3 + col
                # Access individual elements - using flattened array
                dut.matrix[row][col].value = flat_input[idx]
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read output
        flat_output = []
        for row in range(3):
            for col in range(3):
                val = int(dut.sorted_matrix[row][col].value)
                flat_output.append(val)
        
        # Convert to Python format
        result_matrix = verilog_to_matrix(flat_output)
        
        print(f"Expected: {expected_matrix}")
        print(f"Got: {result_matrix}")
        print(f"Row sums (input): {[sum(row) for row in input_matrix]}")
        print(f"Row sums (output): {[sum(row) for row in result_matrix]}")
        
        # Verify
        if result_matrix == expected_matrix:
            print("✓ PASSED")
            passed += 1
        else:
            print("✗ FAILED")
            # Show individual row sums
            input_sums = [sum(row) for row in input_matrix]
            output_sums = [sum(row) for row in result_matrix]
            print(f"  Input row sums: {input_sums}")
            print(f"  Output row sums: {output_sums}")
            print(f"  Expected row sums: {[sum(row) for row in expected_matrix]}")
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed} out of {total} tests passed"

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases"""
    
    edge_cases = [
        # All rows have same sum
        ([[1, 1, 1], [2, 2, 2], [3, 3, 3]], [[1, 1, 1], [2, 2, 2], [3, 3, 3]]),
        # Negative values
        ([[-5, -5, -5], [-1, -1, -1], [-3, -3, -3]], [[-5, -5, -5], [-3, -3, -3], [-1, -1, -1]]),
        # Mixed large and small
        ([[100, 0, 0], [10, 10, 10], [50, 50, 50]], [[10, 10, 10], [50, 50, 50], [100, 0, 0]]),
    ]
    
    passed = 0
    total = len(edge_cases)
    
    for i, (input_matrix, expected_matrix) in enumerate(edge_cases):
        print(f"
Edge Test {i+1}: Input={input_matrix}")
        
        flat_input = matrix_to_verilog(input_matrix)
        
        for row in range(3):
            for col in range(3):
                idx = row * 3 + col
                dut.matrix[row][col].value = flat_input[idx]
        
        await Timer(10, units='ns')
        
        flat_output = []
        for row in range(3):
            for col in range(3):
                val = int(dut.sorted_matrix[row][col].value)
                flat_output.append(val)
        
        result_matrix = verilog_to_matrix(flat_output)
        
        print(f"Expected: {expected_matrix}")
        print(f"Got: {result_matrix}")
        
        if result_matrix == expected_matrix:
            print("✓ PASSED")
            passed += 1
        else:
            print("✗ FAILED")
    
    print(f"
=== EDGE SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed} out of {total} edge tests passed"
