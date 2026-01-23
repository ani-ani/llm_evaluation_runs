import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, FallingEdge
from cocotb.result import TestFailure
import random

def bubble_sort(arr):
    """Sort array using bubble sort for reference"""
    n = len(arr)
    arr_copy = arr[:]
    for i in range(n):
        for j in range(0, n-i-1):
            if arr_copy[j] > arr_copy[j+1]:
                arr_copy[j], arr_copy[j+1] = arr_copy[j+1], arr_copy[j]
    return arr_copy

def compute_expected(arr):
    """Compute expected sum of non-repeated elements"""
    sorted_arr = bubble_sort(arr)
    total = sorted_arr[0]
    for i in range(len(sorted_arr)-1):
        if sorted_arr[i] != sorted_arr[i+1]:
            total += sorted_arr[i+1]
    return total

@cocotb.test()
def test_sum_non_repeated(dut):
    """Test sum of non-repeated elements with various test cases"""
    
    # Test cases from problem
    test_cases = [
        ([1, 2, 3, 1, 1, 4, 5, 6], 21),
        ([1, 10, 9, 4, 2, 10, 10, 45, 4], 71),
        ([12, 10, 9, 45, 2, 10, 10, 45, 10], 78),
        ([5, 5, 5, 5, 5, 5, 5, 5], 5),  # All same
        ([1, 2, 3, 4, 5, 6, 7, 8], 36),  # All different
        ([255, 255, 0, 1, 1, 2, 2, 3], 261),  # Max values
        ([100, 50, 100, 50, 100, 50, 100, 50], 150),  # Alternating pairs
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_arr, expected) in enumerate(test_cases):
        # Pad array to 8 elements if needed
        arr = input_arr[:8]
        if len(arr) < 8:
            arr.extend([0] * (8 - len(arr)))
        
        # Set inputs
        dut.arr_0.value = arr[0]
        dut.arr_1.value = arr[1]
        dut.arr_2.value = arr[2]
        dut.arr_3.value = arr[3]
        dut.arr_4.value = arr[4]
        dut.arr_5.value = arr[5]
        dut.arr_6.value = arr[6]
        dut.arr_7.value = arr[7]
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.sum.value)
        
        # Verify
        if result == expected:
            dut._log.info(f"Test {i+1} passed: arr={arr}, result={result}")
            passed += 1
        else:
            dut._log.error(f"Test {i+1} FAILED: arr={arr}, expected={expected}, got={result}")
            raise TestFailure(f"Test {i+1} failed")
    
    dut._log.info(f"
Summary: {passed}/{total} tests passed")
    
    # Additional random tests
    random.seed(42)
    random_passed = 0
    random_tests = 10
    
    for i in range(random_tests):
        arr = [random.randint(0, 255) for _ in range(8)]
        expected = compute_expected(arr)
        
        dut.arr_0.value = arr[0]
        dut.arr_1.value = arr[1]
        dut.arr_2.value = arr[2]
        dut.arr_3.value = arr[3]
        dut.arr_4.value = arr[4]
        dut.arr_5.value = arr[5]
        dut.arr_6.value = arr[6]
        dut.arr_7.value = arr[7]
        
        await Timer(10, units='ns')
        
        result = int(dut.sum.value)
        
        if result == expected:
            random_passed += 1
        else:
            dut._log.error(f"Random test {i+1} FAILED: arr={arr}, expected={expected}, got={result}")
    
    dut._log.info(f"Random tests: {random_passed}/{random_tests} passed")
    
    total_tests = total + random_tests
    total_passed = passed + random_passed
    dut._log.info(f"
=== FINAL SUMMARY: {total_passed}/{total_tests} tests passed ===")