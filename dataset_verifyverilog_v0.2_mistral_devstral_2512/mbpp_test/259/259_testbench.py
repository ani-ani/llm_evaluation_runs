import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def to_hex(val):
    return f"0x{val:02x}"

@cocotb.test()
async def test_maximize_2d_array(dut):
    """Test element-wise maximization of 4x2 arrays"""
    
    # Test case 1
    dut.array1[0][0] = 1
    dut.array1[0][1] = 3
    dut.array1[1][0] = 4
    dut.array1[1][1] = 5
    dut.array1[2][0] = 2
    dut.array1[2][1] = 9
    dut.array1[3][0] = 1
    dut.array1[3][1] = 10
    
    dut.array2[0][0] = 6
    dut.array2[0][1] = 7
    dut.array2[1][0] = 3
    dut.array2[1][1] = 9
    dut.array2[2][0] = 1
    dut.array2[2][1] = 1
    dut.array2[3][0] = 7
    dut.array2[3][1] = 3
    
    await Timer(1, units='ns')
    
    expected = [
        [6, 7],
        [4, 9],
        [2, 9],
        [7, 10]
    ]
    
    for i in range(4):
        for j in range(2):
            actual = int(dut.result[i][j])
            if actual != expected[i][j]:
                raise TestFailure(f"Test 1 failed at result[{i}][{j}]: expected {expected[i][j]}, got {actual}")
    
    print(f"Test 1 passed: result = [[{dut.result[0][0]}, {dut.result[0][1]}], [{dut.result[1][0]}, {dut.result[1][1]}], [{dut.result[2][0]}, {dut.result[2][1]}], [{dut.result[3][0]}, {dut.result[3][1]}]]")
    
    # Test case 2
    dut.array1[0][0] = 2
    dut.array1[0][1] = 4
    dut.array1[1][0] = 5
    dut.array1[1][1] = 6
    dut.array1[2][0] = 3
    dut.array1[2][1] = 10
    dut.array1[3][0] = 2
    dut.array1[3][1] = 11
    
    dut.array2[0][0] = 7
    dut.array2[0][1] = 8
    dut.array2[1][0] = 4
    dut.array2[1][1] = 10
    dut.array2[2][0] = 2
    dut.array2[2][1] = 2
    dut.array2[3][0] = 8
    dut.array2[3][1] = 4
    
    await Timer(1, units='ns')
    
    expected = [
        [7, 8],
        [5, 10],
        [3, 10],
        [8, 11]
    ]
    
    for i in range(4):
        for j in range(2):
            actual = int(dut.result[i][j])
            if actual != expected[i][j]:
                raise TestFailure(f"Test 2 failed at result[{i}][{j}]: expected {expected[i][j]}, got {actual}")
    
    print(f"Test 2 passed: result = [[{dut.result[0][0]}, {dut.result[0][1]}], [{dut.result[1][0]}, {dut.result[1][1]}], [{dut.result[2][0]}, {dut.result[2][1]}], [{dut.result[3][0]}, {dut.result[3][1]}]]")
    
    # Test case 3
    dut.array1[0][0] = 3
    dut.array1[0][1] = 5
    dut.array1[1][0] = 6
    dut.array1[1][1] = 7
    dut.array1[2][0] = 4
    dut.array1[2][1] = 11
    dut.array1[3][0] = 3
    dut.array1[3][1] = 12
    
    dut.array2[0][0] = 8
    dut.array2[0][1] = 9
    dut.array2[1][0] = 5
    dut.array2[1][1] = 11
    dut.array2[2][0] = 3
    dut.array2[2][1] = 3
    dut.array2[3][0] = 9
    dut.array2[3][1] = 5
    
    await Timer(1, units='ns')
    
    expected = [
        [8, 9],
        [6, 11],
        [4, 11],
        [9, 12]
    ]
    
    for i in range(4):
        for j in range(2):
            actual = int(dut.result[i][j])
            if actual != expected[i][j]:
                raise TestFailure(f"Test 3 failed at result[{i}][{j}]: expected {expected[i][j]}, got {actual}")
    
    print(f"Test 3 passed: result = [[{dut.result[0][0]}, {dut.result[0][1]}], [{dut.result[1][0]}, {dut.result[1][1]}], [{dut.result[2][0]}, {dut.result[2][1]}], [{dut.result[3][0]}, {dut.result[3][1]}]]")
    
    # Edge case: all equal values
    dut.array1[0][0] = 5
    dut.array1[0][1] = 5
    dut.array1[1][0] = 5
    dut.array1[1][1] = 5
    dut.array1[2][0] = 5
    dut.array1[2][1] = 5
    dut.array1[3][0] = 5
    dut.array1[3][1] = 5
    
    dut.array2[0][0] = 5
    dut.array2[0][1] = 5
    dut.array2[1][0] = 5
    dut.array2[1][1] = 5
    dut.array2[2][0] = 5
    dut.array2[2][1] = 5
    dut.array2[3][0] = 5
    dut.array2[3][1] = 5
    
    await Timer(1, units='ns')
    
    for i in range(4):
        for j in range(2):
            actual = int(dut.result[i][j])
            if actual != 5:
                raise TestFailure(f"Edge case failed at result[{i}][{j}]: expected 5, got {actual}")
    
    print(f"Edge case passed: all equal values")
    
    # Edge case: max values (255)
    dut.array1[0][0] = 255
    dut.array1[0][1] = 255
    dut.array1[1][0] = 255
    dut.array1[1][1] = 255
    dut.array1[2][0] = 255
    dut.array1[2][1] = 255
    dut.array1[3][0] = 255
    dut.array1[3][1] = 255
    
    dut.array2[0][0] = 255
    dut.array2[0][1] = 255
    dut.array2[1][0] = 255
    dut.array2[1][1] = 255
    dut.array2[2][0] = 255
    dut.array2[2][1] = 255
    dut.array2[3][0] = 255
    dut.array2[3][1] = 255
    
    await Timer(1, units='ns')
    
    for i in range(4):
        for j in range(2):
            actual = int(dut.result[i][j])
            if actual != 255:
                raise TestFailure(f"Max value edge case failed at result[{i}][{j}]: expected 255, got {actual}")
    
    print(f"Max value edge case passed")
    
    print(f"
Summary: 5/5 tests passed")