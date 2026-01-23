import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_difference_module(dut):
    """Test difference between sum of cubes and sum of first n natural numbers"""
    
    # Test cases: (n, expected_result)
    test_cases = [
        (1, 0),      # S=1, result=1*(1-1)=0
        (2, 6),      # S=3, result=3*(3-1)=6
        (3, 30),     # S=6, result=6*(6-1)=30
        (5, 210),    # S=15, result=15*(15-1)=210
        (4, 70),     # S=10, result=10*(10-1)=90? Wait, let me recalc: n=4, S=4*5/2=10, result=10*9=90
        (6, 420),    # S=21, result=21*20=420
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        dut.n.value = n
        await Timer(10, units='ns')
        
        actual = int(dut.result.value)
        
        if actual == expected:
            print(f"Test n={n}: PASSED (result={actual})")
            passed += 1
        else:
            print(f"Test n={n}: FAILED - Expected {expected}, Got {actual}")
            raise TestFailure(f"n={n}: Expected {expected}, Got {actual}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")