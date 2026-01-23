import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

class PairTester:
    def __init__(self, dut):
        self.dut = dut
        
    def count_unequal_pairs(self, arr):
        """Reference Python implementation for validation"""
        n = len(arr)
        cnt = 0
        for i in range(n):
            for j in range(i + 1, n):
                if arr[i] != arr[j]:
                    cnt += 1
        return cnt
    
    def scale_array(self, arr):
        """Convert Python list to list of 8-bit integers"""
        return [x & 0xFF for x in arr]

@cocotb.test()
async def test_unequal_pair_counter(dut):
    """Test the unequal pair counter module"""
    
    tester = PairTester(dut)
    
    # Initialize all inputs
    dut.arr.value = [0] * 8
    
    # Wait a bit for initialization
    await Timer(10, units='ns')
    
    print("
=== Testing Unequal Pair Counter ===")
    
    # Test Case 1: [1,2,1,0,0,0,0,0] -> Expected: 2
    # Original: [1,2,1] with 2 unequal pairs
    arr1 = [1, 2, 1] + [0, 0, 0, 0, 0]  # Pad to 8 elements
    arr1_scaled = tester.scale_array(arr1)
    dut.arr.value = arr1_scaled
    await Timer(10, units='ns')
    result1 = int(dut.count.value)
    expected1 = tester.count_unequal_pairs(arr1_scaled)
    print(f"Test 1: arr={arr1_scaled[:3]} (padded) -> got {result1}, expected {expected1}")
    assert result1 == expected1, f"Test 1 failed: got {result1}, expected {expected1}"
    
    # Test Case 2: [1,1,1,1,0,0,0,0] -> Expected: 0
    # Original: [1,1,1,1] with 0 unequal pairs
    arr2 = [1, 1, 1, 1] + [0, 0, 0, 0]  # Pad to 8 elements
    arr2_scaled = tester.scale_array(arr2)
    dut.arr.value = arr2_scaled
    await Timer(10, units='ns')
    result2 = int(dut.count.value)
    expected2 = tester.count_unequal_pairs(arr2_scaled)
    print(f"Test 2: arr={arr2_scaled[:4]} (padded) -> got {result2}, expected {expected2}")
    assert result2 == expected2, f"Test 2 failed: got {result2}, expected {expected2}"
    
    # Test Case 3: [1,2,3,4,5,0,0,0] -> Expected: 10
    # Original: [1,2,3,4,5] with 10 unequal pairs (C(5,2)=10)
    arr3 = [1, 2, 3, 4, 5, 0, 0, 0]  # Pad to 8 elements
    arr3_scaled = tester.scale_array(arr3)
    dut.arr.value = arr3_scaled
    await Timer(10, units='ns')
    result3 = int(dut.count.value)
    expected3 = tester.count_unequal_pairs(arr3_scaled)
    print(f"Test 3: arr={arr3_scaled[:5]} (padded) -> got {result3}, expected {expected3}")
    assert result3 == expected3, f"Test 3 failed: got {result3}, expected {expected3}"
    
    # Test Case 4: Edge case - all same values
    arr4 = [42, 42, 42, 42, 42, 42, 42, 42]
    arr4_scaled = tester.scale_array(arr4)
    dut.arr.value = arr4_scaled
    await Timer(10, units='ns')
    result4 = int(dut.count.value)
    expected4 = tester.count_unequal_pairs(arr4_scaled)
    print(f"Test 4: arr={arr4_scaled} -> got {result4}, expected {expected4}")
    assert result4 == expected4, f"Test 4 failed: got {result4}, expected {expected4}"
    
    # Test Case 5: Edge case - alternating values
    arr5 = [0, 1, 0, 1, 0, 1, 0, 1]
    arr5_scaled = tester.scale_array(arr5)
    dut.arr.value = arr5_scaled
    await Timer(10, units='ns')
    result5 = int(dut.count.value)
    expected5 = tester.count_unequal_pairs(arr5_scaled)
    print(f"Test 5: arr={arr5_scaled} -> got {result5}, expected {expected5}")
    assert result5 == expected5, f"Test 5 failed: got {result5}, expected {expected5}"
    
    # Test Case 6: Edge case - max values
    arr6 = [0xFF, 0xFE, 0xFD, 0xFC, 0xFB, 0xFA, 0xF9, 0xF8]
    dut.arr.value = arr6
    await Timer(10, units='ns')
    result6 = int(dut.count.value)
    expected6 = tester.count_unequal_pairs(arr6)
    print(f"Test 6: arr={arr6} -> got {result6}, expected {expected6}")
    assert result6 == expected6, f"Test 6 failed: got {result6}, expected {expected6}"
    
    print("
=== All tests passed! ===")
    print(f"Total tests: 6, Passed: 6")
