import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_matrix_addition(dut):
    """Test matrix addition with multiple test cases"""
    
    # Test cases adapted from the original nested tuple problem
    test_cases = [
        # Test 1: ((1,3),(4,5),(2,9),(1,10)) + ((6,7),(3,9),(1,1),(7,3))
        {
            'a': [[1, 3], [4, 5], [2, 9], [1, 10]],
            'b': [[6, 7], [3, 9], [1, 1], [7, 3]],
            'expected': [[7, 10], [7, 14], [3, 10], [8, 13]]
        },
        # Test 2: ((2,4),(5,6),(3,10),(2,11)) + ((7,8),(4,10),(2,2),(8,4))
        {
            'a': [[2, 4], [5, 6], [3, 10], [2, 11]],
            'b': [[7, 8], [4, 10], [2, 2], [8, 4]],
            'expected': [[9, 12], [9, 16], [5, 12], [10, 15]]
        },
        # Test 3: ((3,5),(6,7),(4,11),(3,12)) + ((8,9),(5,11),(3,3),(9,5))
        {
            'a': [[3, 5], [6, 7], [4, 11], [3, 12]],
            'b': [[8, 9], [5, 11], [3, 3], [9, 5]],
            'expected': [[11, 14], [11, 18], [7, 14], [12, 17]]
        },
        # Edge case: all zeros
        {
            'a': [[0, 0], [0, 0], [0, 0], [0, 0]],
            'b': [[0, 0], [0, 0], [0, 0], [0, 0]],
            'expected': [[0, 0], [0, 0], [0, 0], [0, 0]]
        },
        # Edge case: max values (255 + 0)
        {
            'a': [[255, 255], [255, 255], [255, 255], [255, 255]],
            'b': [[0, 0], [0, 0], [0, 0], [0, 0]],
            'expected': [[255, 255], [255, 255], [255, 255], [255, 255]]
        },
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, test in enumerate(test_cases):
        dut._log.info(f"Running test case {i+1}")
        
        # Set inputs
        for row in range(4):
            for col in range(2):
                setattr(dut, f"matrix_a_{row}_{col}", test['a'][row][col])
                setattr(dut, f"matrix_b_{row}_{col}", test['b'][row][col])
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Check outputs
        all_correct = True
        for row in range(4):
            for col in range(2):
                actual = getattr(dut, f"matrix_sum_{row}_{col}").value
                expected = test['expected'][row][col]
                if int(actual) != expected:
                    dut._log.error(f"Test {i+1} failed at [{row}][{col}]: expected {expected}, got {int(actual)}")
                    all_correct = False
        
        if all_correct:
            dut._log.info(f"Test case {i+1} passed")
            passed += 1
    
    dut._log.info(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
