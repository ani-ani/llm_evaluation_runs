import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

def is_monge(matrix, r, c):
    """Check if matrix of size r x c is extremely cool (Monge)."""
    if r < 2 or c < 2:
        return True
    for i in range(r - 1):
        for j in range(c - 1):
            a = matrix[i * c + j]
            b = matrix[i * c + j + 1]
            c_val = matrix[(i + 1) * c + j]
            d = matrix[(i + 1) * c + j + 1]
            if a + d > b + c_val:
                return False
    return True

@cocotb.test()
async def test_extremely_cool_checker(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.rows.value = 0
    dut.cols.value = 0
    for i in range(64):
        setattr(dut.matrix_data, f'[{i}]', 0)
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: 3x3 Sample 1 (Should be Extremely Cool -> 9 elements)
    # Matrix:
    # 1  4 10
    # 5  2  6
    # 11 1  3
    # Check 2x2s:
    # 1,4 / 5,2 -> 1+2 <= 4+5 (3 <= 9) OK
    # 4,10 / 2,6 -> 4+6 <= 10+2 (10 <= 12) OK
    # 5,2 / 11,1 -> 5+1 <= 2+11 (6 <= 13) OK
    # 2,6 / 1,3 -> 2+3 <= 6+1 (5 <= 7) OK
    matrix1 = [1, 4, 10, 5, 2, 6, 11, 1, 3]
    for i, val in enumerate(matrix1):
        setattr(dut.matrix_data, f'[{i}]', val)
    dut.rows.value = 3
    dut.cols.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.is_cool.value == 1, "Test 1 Failed: 3x3 matrix should be extremely cool"
    print("Test 1 Passed: 3x3 matrix is extremely cool")

    # Test Case 2: 3x3 Sample 2 (Not extremely cool -> 4 elements)
    # Matrix:
    # 1 3 1
    # 2 1 2
    # 1 1 1
    # Check 2x2s:
    # 1,3 / 2,1 -> 1+1 <= 3+2 (2 <= 5) OK
    # 3,1 / 1,2 -> 3+2 <= 1+1 (5 <= 2) FAIL
    matrix2 = [1, 3, 1, 2, 1, 2, 1, 1, 1]
    for i, val in enumerate(matrix2):
        setattr(dut.matrix_data, f'[{i}]', val)
    dut.rows.value = 3
    dut.cols.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.is_cool.value == 0, "Test 2 Failed: 3x3 matrix should NOT be extremely cool"
    print("Test 2 Passed: 3x3 matrix is not extremely cool")

    # Test Case 3: 2x2 Submatrix from Sample 2 (Should be Extremely Cool)
    # Using top-left 2x2:
    # 1 3
    # 2 1
    # Check: 1+1 <= 3+2 (2 <= 5) OK
    matrix3 = [1, 3, 2, 1]
    for i, val in enumerate(matrix3):
        setattr(dut.matrix_data, f'[{i}]', val)
    dut.rows.value = 2
    dut.cols.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.is_cool.value == 1, "Test 3 Failed: 2x2 submatrix should be extremely cool"
    print("Test 3 Passed: 2x2 submatrix is extremely cool")

    # Test Case 4: 1x1 Matrix (Trivially extremely cool)
    setattr(dut.matrix_data, f'[0]', 5)
    dut.rows.value = 1
    dut.cols.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.is_cool.value == 1, "Test 4 Failed: 1x1 matrix should be extremely cool"
    print("Test 4 Passed: 1x1 matrix is extremely cool")

    # Test Case 5: 2x3 Matrix
    # 10 20 30
    # 15 25 35
    # Checks:
    # (0,0): 10+25 <= 20+15 -> 35 <= 35 OK
    # (0,1): 20+35 <= 30+25 -> 55 <= 55 OK
    matrix5 = [10, 20, 30, 15, 25, 35]
    for i, val in enumerate(matrix5):
        setattr(dut.matrix_data, f'[{i}]', val)
    dut.rows.value = 2
    dut.cols.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.is_cool.value == 1, "Test 5 Failed: 2x3 matrix should be extremely cool"
    print("Test 5 Passed: 2x3 matrix is extremely cool")

    print("All tests passed!")