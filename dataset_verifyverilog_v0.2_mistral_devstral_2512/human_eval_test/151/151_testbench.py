import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_double_the_difference(dut):
    """Test double_the_difference module"""
    
    # Test cases from problem
    test_cases = [
        ([0, 0, 0, 0, 0, 0, 0, 0], 0),           # Empty/zero case
        ([1, 3, 2, 0, 0, 0, 0, 0], 10),          # Original: [1, 3, 2, 0]
        ([-1, -2, 0, 0, 0, 0, 0, 0], 0),         # All negative
        ([9, -2, 0, 0, 0, 0, 0, 0], 81),         # Positive odd with negative
        ([5, 4, 0, 0, 0, 0, 0, 0], 25),          # Test case 1
        ([-10, -20, -30, 0, 0, 0, 0, 0], 0),     # All negative
        ([3, 5, 0, 0, 0, 0, 0, 0], 34),          # 3^2 + 5^2 = 9 + 25 = 34
        # Edge cases with values near limits
        ([127, 126, 1, 0, 0, 0, 0, 0], 127*127 + 1),  # Max 8-bit signed + odd
        ([-128, -1, 0, 0, 0, 0, 0, 0], 0),       # Min 8-bit signed
        ([0, 1, 2, 3, 4, 5, 6, 7], 1+9+25+49),   # 0-7, odd squares
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (nums, expected) in enumerate(test_cases):
        # Set inputs
        for j in range(8):
            setattr(dut, f'nums_{j}', nums[j])
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        actual = int(dut.result.value)
        
        if actual == expected:
            passed += 1
            print(f"Test {i+1}: PASS - Input={nums[:4]}..., Expected={expected}, Got={actual}")
        else:
            print(f"Test {i+1}: FAIL - Input={nums[:4]}..., Expected={expected}, Got={actual}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Failed {total - passed} tests"
