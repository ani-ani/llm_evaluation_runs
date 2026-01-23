import cocotb
from cocotb.triggers import Timer
import random

def popcount_8bit(n):
    """Calculate number of set bits in 8-bit number"""
    return bin(n).count('1')

def custom_sort_key(val):
    """Return tuple (popcount, value) for sorting"""
    return (popcount_8bit(val), val)

def python_sorted(arr):
    """Python reference implementation"""
    return sorted(arr, key=custom_sort_key)

@cocotb.test()
async def test_sort_array(dut):
    """Test the sort_array module with various cases"""
    
    # Test cases adapted for 8-element array (use 0 for unused slots)
    test_cases = [
        [1, 5, 2, 3, 4, 0, 0, 0],  # Original test case 1 (padded)
        [1, 0, 2, 3, 4, 0, 0, 0],  # Original test case 2
        [2, 5, 77, 4, 5, 3, 5, 7], # Original test case 3 (8 elements)
        [3, 6, 44, 12, 32, 5, 0, 0], # Original test case 4
        [2, 4, 8, 16, 32, 0, 0, 0], # Powers of 2
        [255, 128, 64, 32, 16, 8, 4, 2], # High popcount values
        [0, 1, 3, 7, 15, 31, 63, 127], # Increasing popcount
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, inputs in enumerate(test_cases):
        # Assign inputs
        dut.in_0.value = inputs[0]
        dut.in_1.value = inputs[1]
        dut.in_2.value = inputs[2]
        dut.in_3.value = inputs[3]
        dut.in_4.value = inputs[4]
        dut.in_5.value = inputs[5]
        dut.in_6.value = inputs[6]
        dut.in_7.value = inputs[7]
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read outputs
        outputs = [
            int(dut.out_0.value),
            int(dut.out_1.value),
            int(dut.out_2.value),
            int(dut.out_3.value),
            int(dut.out_4.value),
            int(dut.out_5.value),
            int(dut.out_6.value),
            int(dut.out_7.value)
        ]
        
        # Calculate expected output
        expected = python_sorted(inputs)
        
        # Filter out zeros for comparison (to match original test semantics)
        original_len = len([x for x in inputs if x != 0 or inputs.index(x) < 5])
        outputs_filtered = outputs[:original_len]
        expected_filtered = expected[:original_len]
        
        # Check
        if outputs_filtered == expected_filtered:
            passed += 1
            print(f"Test {i+1} PASS: {inputs[:5]}... -> {outputs_filtered}")
        else:
            print(f"Test {i+1} FAIL: Input {inputs[:5]}...")
            print(f"  Expected: {expected_filtered}")
            print(f"  Got:      {outputs_filtered}")
    
    # Edge case: all zeros
    dut.in_0.value = 0
    dut.in_1.value = 0
    dut.in_2.value = 0
    dut.in_3.value = 0
    dut.in_4.value = 0
    dut.in_5.value = 0
    dut.in_6.value = 0
    dut.in_7.value = 0
    await Timer(10, units='ns')
    
    zeros_out = [int(dut.out_0.value), int(dut.out_1.value), int(dut.out_2.value), int(dut.out_3.value),
                 int(dut.out_4.value), int(dut.out_5.value), int(dut.out_6.value), int(dut.out_7.value)]
    
    if zeros_out == [0, 0, 0, 0, 0, 0, 0, 0]:
        passed += 1
        print("Test edge_case_zeros PASS")
    else:
        print(f"Test edge_case_zeros FAIL: {zeros_out}")
    
    total += 1
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"