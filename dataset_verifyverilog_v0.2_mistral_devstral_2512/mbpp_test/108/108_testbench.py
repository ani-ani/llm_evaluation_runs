import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

def merge_sorted_list_py(num1, num2, num3):
    num1 = sorted(num1)
    num2 = sorted(num2)
    num3 = sorted(num3)
    result = []
    i = j = k = 0
    while i < len(num1) or j < len(num2) or k < len(num3):
        val1 = num1[i] if i < len(num1) else float('inf')
        val2 = num2[j] if j < len(num2) else float('inf')
        val3 = num3[k] if k < len(num3) else float('inf')
        if val1 <= val2 and val1 <= val3:
            result.append(val1)
            i += 1
        elif val2 <= val1 and val2 <= val3:
            result.append(val2)
            j += 1
        else:
            result.append(val3)
            k += 1
    return result

@cocotb.test()
async def test_merge_three_lists(dut):
    # Test cases from the problem
    test_cases = [
        ([25, 24, 15, 4, 5, 29, 110], [19, 20, 11, 56, 25, 233, 154], [24, 26, 54, 48]),
        ([1, 3, 5, 6, 8, 9], [2, 5, 7, 11], [1, 4, 7, 8, 12]),
        ([18, 14, 10, 9, 8, 7, 9, 3, 2, 4, 1], [25, 35, 22, 85, 14, 65, 75, 25, 58], [12, 74, 9, 50, 61, 41])
    ]
    
    # Additional edge cases
    edge_cases = [
        ([], [], []),  # All empty
        ([1], [], []),  # Single element
        ([1, 2, 3], [1, 2, 3], [1, 2, 3]),  # All same
        ([100], [50], [75]),  # Reverse order single elements
        ([1, 2, 3, 4, 5, 6, 7, 8], [9, 10, 11, 12], [13, 14])  # Full capacity
    ]
    
    all_cases = test_cases + edge_cases
    passed = 0
    total = len(all_cases)
    
    for idx, (l1, l2, l3) in enumerate(all_cases):
        # Sort input lists (Python does this, but we assume pre-sorted for HW)
        l1_sorted = sorted(l1)
        l2_sorted = sorted(l2)
        l3_sorted = sorted(l3)
        
        # Get expected result
        expected = merge_sorted_list_py(l1_sorted, l2_sorted, l3_sorted)
        
        # Pad input arrays to max size (8 for list1/2/3)
        list1_input = l1_sorted + [0] * (8 - len(l1_sorted))
        list2_input = l2_sorted + [0] * (8 - len(l2_sorted))
        list3_input = l3_sorted + [0] * (8 - len(l3_sorted))
        
        # Drive inputs
        dut.list1_size.value = len(l1_sorted)
        dut.list2_size.value = len(l2_sorted)
        dut.list3_size.value = len(l3_sorted)
        
        # Set array inputs - note Verilog array indexing
        for i in range(8):
            dut.list1[i].value = list1_input[i]
            dut.list2[i].value = list2_input[i]
            dut.list3[i].value = list3_input[i]
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read result
        result_size = int(dut.result_size.value)
        result_array = []
        for i in range(24):
            val = int(dut.result[i].value)
            if i < result_size:
                result_array.append(val)
        
        # Verify
        if result_size != len(expected):
            print(f"Test {idx+1} FAILED: Expected size {len(expected)}, got {result_size}")
            print(f"  Input1: {l1_sorted}, Input2: {l2_sorted}, Input3: {l3_sorted}")
            print(f"  Expected: {expected}")
            print(f"  Got: {result_array}")
            continue
        
        if result_array != expected:
            print(f"Test {idx+1} FAILED: Result mismatch")
            print(f"  Input1: {l1_sorted}, Input2: {l2_sorted}, Input3: {l3_sorted}")
            print(f"  Expected: {expected}")
            print(f"  Got: {result_array}")
            continue
        
        passed += 1
        print(f"Test {idx+1} PASSED")
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"{total - passed} tests failed")