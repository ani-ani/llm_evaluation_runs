import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Constants for the 4x2 matrix
MATRIX_ROWS = 4
MATRIX_COLS = 2
DATA_WIDTH = 4

def clamp_to_width(v, bits):
    """Clamp value to specified bit width (unsigned)"""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def write_matrix(dut, matrix_name, matrix_vals):
    """Write 4x2 matrix values to DUT port"""
    for r in range(MATRIX_ROWS):
        for c in range(MATRIX_COLS):
            val = clamp_to_width(matrix_vals[r][c], DATA_WIDTH)
            dut.__getattr__(matrix_name)[r][c].value = val

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_maximize_matrix(dut):
    """Test element-wise maximum of two 4x2 matrices"""
    
    # Test cases from the problem
    test_cases = [
        (
            [[1, 3], [4, 5], [2, 9], [1, 10]],  # matrix1
            [[6, 7], [3, 9], [1, 1], [7, 3]],  # matrix2
            [[6, 7], [4, 9], [2, 9], [7, 10]]   # expected result
        ),
        (
            [[2, 4], [5, 6], [3, 10], [2, 11]],
            [[7, 8], [4, 10], [2, 2], [8, 4]],
            [[7, 8], [5, 10], [3, 10], [8, 11]]
        ),
        (
            [[3, 5], [6, 7], [4, 11], [3, 12]],
            [[8, 9], [5, 11], [3, 3], [9, 5]],
            [[8, 9], [6, 11], [4, 11], [9, 12]]
        )
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (matrix1_vals, matrix2_vals, expected_result) in enumerate(test_cases):
        cocotb.log.info(f"\nTest case {test_idx + 1}: Comparing matrices")
        
        try:
            # Write input matrices
            write_matrix(dut, 'matrix1', matrix1_vals)
            write_matrix(dut, 'matrix2', matrix2_vals)
            
            # Propagate through combinational logic
            await Timer(100, units='ns')
            
            # Read output matrix
            actual_result = [[0] * MATRIX_COLS for _ in range(MATRIX_ROWS)]
            for r in range(MATRIX_ROWS):
                for c in range(MATRIX_COLS):
                    result_val = int(dut.result[r][c].value)
                    actual_result[r][c] = result_val
            
            # Verify each element
            if actual_result != expected_result:
                raise TestFailure(
                    f"Test {test_idx + 1} failed\n"
                    f"Expected: {expected_result}\n"
                    f"Got: {actual_result}"
                )
            
            cocotb.log.info(f"Test {test_idx + 1}: PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {test_idx + 1}: FAIL\n{e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"\n{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"\nAll {passed} tests passed successfully!")