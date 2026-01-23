import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

def sort_and_select(data, n):
    """Sort data descending and return first n elements"""
    sorted_data = sorted(data, reverse=True)
    return sorted_data[:min(n, len(data))]

@cocotb.test()
async def test_largest_n_finder(dut):
    """Test the largest_n_finder module"""
    
    print("
=== Testing largest_n_finder module ===")
    
    test_cases = [
        # (data_in, n, expected_result)
        ([10, 20, 50, 70, 90, 20, 50, 40], 2, [100, 90]),  # Adapted from Test 1
        ([10, 20, 50, 70, 90, 20, 50, 40], 5, [100, 90, 80, 70, 60]),  # Adapted from Test 2
        ([10, 20, 50, 70, 90, 20, 50, 40], 3, [100, 90, 80]),  # Adapted from Test 3
        ([100, 90, 80, 70, 60, 50, 40, 30], 4, [100, 90, 80, 70]),  # Already sorted
        ([30, 40, 50, 60, 70, 80, 90, 100], 4, [100, 90, 80, 70]),  # Reverse sorted
        ([50, 50, 50, 50, 50, 50, 50, 50], 3, [50, 50, 50]),  # All equal
        ([1, 2, 3, 4, 5, 6, 7, 8], 1, [8]),  # n=1
        ([255, 0, 128, 64, 192, 32, 160, 96], 4, [255, 192, 160, 128]),  # Edge values
        ([0, 0, 0, 0, 0, 0, 0, 0], 2, [0, 0]),  # All zeros
        ([10, 20, 30, 40, 50, 60, 70, 80], 2, [80, 70]),  # Simple case
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (data, n, expected) in enumerate(test_cases):
        # Set inputs
        for j in range(8):
            setattr(dut, f"data_in_{j}", data[j])
        dut.n.value = n
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read outputs
        result = [int(dut.result_0), int(dut.result_1), int(dut.result_2), int(dut.result_3)]
        
        # Check result
        # Expected: first n elements in descending order, rest padded with 0
        for k in range(4):
            if k < n:
                if result[k] != expected[k]:
                    print(f"Test {i+1} FAILED: n={n}, index={k}")
                    print(f"  Expected: {expected}")
                    print(f"  Got: {result}")
                    raise TestFailure(f"Mismatch at test {i+1}, position {k}")
            else:
                if result[k] != 0:
                    print(f"Test {i+1} FAILED: Expected 0 in unused position {k}, got {result[k]}")
                    raise TestFailure(f"Non-zero in unused position at test {i+1}")
        
        print(f"Test {i+1} PASSED: n={n}, data={data[:4]}..., result={result}")
        passed += 1
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")

@cocotb.test()
async def test_largest_n_corner_cases(dut):
    """Test corner cases for largest_n_finder"""
    
    print("
=== Testing corner cases ===")
    
    # Test with n=0 (should return all zeros)
    setattr(dut, "data_in_0", 100)
    setattr(dut, "data_in_1", 90)
    setattr(dut, "data_in_2", 80)
    setattr(dut, "data_in_3", 70)
    setattr(dut, "data_in_4", 60)
    setattr(dut, "data_in_5", 50)
    setattr(dut, "data_in_6", 40)
    setattr(dut, "data_in_7", 30)
    dut.n.value = 0
    await Timer(10, units='ns')
    
    result = [int(dut.result_0), int(dut.result_1), int(dut.result_2), int(dut.result_3)]
    if result != [0, 0, 0, 0]:
        print(f"n=0 test FAILED: expected [0,0,0,0], got {result}")
        raise TestFailure("n=0 case failed")
    print(f"n=0 test PASSED: {result}")
    
    # Test with maximum n=4
    dut.n.value = 4
    await Timer(10, units='ns')
    result = [int(dut.result_0), int(dut.result_1), int(dut.result_2), int(dut.result_3)]
    expected = [100, 90, 80, 70]
    if result != expected:
        print(f"n=4 test FAILED: expected {expected}, got {result}")
        raise TestFailure("n=4 case failed")
    print(f"n=4 test PASSED: {result}")
    
    print("
=== Corner cases: 2/2 passed ===")
