import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_exchange_checker(dut):
    """Test the exchange checker module"""
    
    # Helper function to count odd numbers in a list
    def count_odd(lst):
        return sum(1 for x in lst if x % 2 != 0)
    
    # Test cases adapted for 8-element arrays
    # Format: (lst1, lst2, expected_result_string)
    test_cases = [
        ([1, 2, 3, 4, 0, 0, 0, 0], [1, 2, 3, 4, 0, 0, 0, 0], "YES"),
        ([1, 2, 3, 4, 0, 0, 0, 0], [1, 5, 3, 4, 0, 0, 0, 0], "NO"),
        ([1, 2, 3, 4, 0, 0, 0, 0], [2, 1, 4, 3, 0, 0, 0, 0], "YES"),
        ([5, 7, 3, 0, 0, 0, 0, 0], [2, 6, 4, 0, 0, 0, 0, 0], "YES"),
        ([5, 7, 3, 0, 0, 0, 0, 0], [2, 6, 3, 0, 0, 0, 0, 0], "NO"),
        ([3, 2, 6, 1, 8, 9, 0, 0], [3, 5, 5, 1, 1, 1, 0, 0], "NO"),
        ([100, 200, 0, 0, 0, 0, 0, 0], [200, 200, 0, 0, 0, 0, 0, 0], "YES"),
        # Edge cases
        ([255, 255, 255, 255, 255, 255, 255, 255], [255, 255, 255, 255, 255, 255, 255, 255], "YES"), # 8 odds vs 8 odds (equal)
        ([255, 255, 255, 255, 0, 0, 0, 0], [255, 255, 0, 0, 0, 0, 0, 0], "NO") # 4 odds vs 2 odds
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (l1, l2, expected_str) in enumerate(test_cases):
        # Assign inputs to DUT
        for j in range(8):
            dut.lst1[j].value = l1[j]
            dut.lst2[j].value = l2[j]
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Determine expected binary value
        odd_in = count_odd(l1)
        odd_out = count_odd(l2)
        expected = 1 if odd_in <= odd_out else 0
        
        actual = int(dut.result.value)
        
        if actual == expected:
            passed += 1
            print(f"Test {i+1} PASSED: {l1[:3]}... vs {l2[:3]}... => Expected {expected_str} ({expected}), Got {actual}")
        else:
            print(f"Test {i+1} FAILED: {l1[:3]}... vs {l2[:3]}... => Expected {expected} ({expected_str}), Got {actual}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total
