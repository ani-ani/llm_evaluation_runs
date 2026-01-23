import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_of_nth(dut):
    """Test max_of_nth module with various matrix configurations"""
    
    # Test case 1: max_of_nth([[5, 6, 7], [1, 3, 5], [8, 9, 19]], 2) == 19
    dut.matrix.value = [[5, 6, 7], [1, 3, 5], [8, 9, 19]]
    dut.column_index.value = 2
    await Timer(10, units='ns')
    result = int(dut.max_value)
    print(f"Test 1: matrix=[[5,6,7],[1,3,5],[8,9,19]], col=2, result={result}, expected=19")
    assert result == 19, f"Test 1 failed: expected 19, got {result}"
    
    # Test case 2: max_of_nth([[6, 7, 8], [2, 4, 6], [9, 10, 20]], 1) == 10
    dut.matrix.value = [[6, 7, 8], [2, 4, 6], [9, 10, 20]]
    dut.column_index.value = 1
    await Timer(10, units='ns')
    result = int(dut.max_value)
    print(f"Test 2: matrix=[[6,7,8],[2,4,6],[9,10,20]], col=1, result={result}, expected=10")
    assert result == 10, f"Test 2 failed: expected 10, got {result}"
    
    # Test case 3: max_of_nth([[7, 8, 9], [3, 5, 7], [10, 11, 21]], 1) == 11
    dut.matrix.value = [[7, 8, 9], [3, 5, 7], [10, 11, 21]]
    dut.column_index.value = 1
    await Timer(10, units='ns')
    result = int(dut.max_value)
    print(f"Test 3: matrix=[[7,8,9],[3,5,7],[10,11,21]], col=1, result={result}, expected=11")
    assert result == 11, f"Test 3 failed: expected 11, got {result}"
    
    # Additional edge case: column 0 with different values
    dut.matrix.value = [[100, 1, 2], [50, 3, 4], [75, 5, 6]]
    dut.column_index.value = 0
    await Timer(10, units='ns')
    result = int(dut.max_value)
    print(f"Test 4: matrix=[[100,1,2],[50,3,4],[75,5,6]], col=0, result={result}, expected=100")
    assert result == 100, f"Test 4 failed: expected 100, got {result}"
    
    # Edge case: all equal values in a column
    dut.matrix.value = [[42, 0, 0], [42, 1, 1], [42, 2, 2]]
    dut.column_index.value = 0
    await Timer(10, units='ns')
    result = int(dut.max_value)
    print(f"Test 5: matrix=[[42,0,0],[42,1,1],[42,2,2]], col=0, result={result}, expected=42")
    assert result == 42, f"Test 5 failed: expected 42, got {result}"
    
    print("
All 5 tests passed!")
