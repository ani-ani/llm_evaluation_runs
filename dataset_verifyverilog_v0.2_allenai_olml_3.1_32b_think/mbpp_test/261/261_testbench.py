import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_tuple_division(dut):
    """Test element-wise division of 4-element tuples"""
    
    # Test case 1: Original test case
    dividend1 = [10, 4, 6, 9]
    divisor1 = [5, 2, 3, 3]
    expected1 = [2, 2, 2, 3]
    
    # Test case 2: Original test case
    dividend2 = [12, 6, 8, 16]
    divisor2 = [6, 3, 4, 4]
    expected2 = [2, 2, 2, 4]
    
    # Test case 3: Original test case
    dividend3 = [20, 14, 36, 18]
    divisor3 = [5, 7, 6, 9]
    expected3 = [4, 2, 6, 2]
    
    # Test case 4: Edge case with small values
    dividend4 = [0, 1, 15, 255]
    divisor4 = [1, 1, 3, 255]
    expected4 = [0, 1, 5, 1]
    
    # Test case 5: Edge case with larger values
    dividend5 = [100, 75, 255, 200]
    divisor5 = [10, 15, 17, 20]
    expected5 = [10, 5, 15, 10]
    
    test_cases = [
        (dividend1, divisor1, expected1),
        (dividend2, divisor2, expected2),
        (dividend3, divisor3, expected3),
        (dividend4, divisor4, expected4),
        (dividend5, divisor5, expected5),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (dividend, divisor, expected) in enumerate(test_cases):
        # Set inputs
        for j in range(4):
            setattr(dut.dividend, f'[{j}]', dividend[j])
            setattr(dut.divisor, f'[{j}]', divisor[j])
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read outputs
        actual = [int(getattr(dut.quotient, f'[{j}]')) for j in range(4)]
        
        # Verify
        if actual == expected:
            passed += 1
            print(f"Test {i+1}: PASS - Dividend {dividend}, Divisor {divisor}, Result {actual}")
        else:
            print(f"Test {i+1}: FAIL - Dividend {dividend}, Divisor {divisor}")
            print(f"  Expected: {expected}")
            print(f"  Got: {actual}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
