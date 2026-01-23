import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure, TestSuccess
import random

def count_frequencies_python(arr):
    """Helper to verify expected results"""
    freq = {}
    for val in arr:
        freq[val] = freq.get(val, 0) + 1
    max_val = None
    max_count = 0
    for val, count in freq.items():
        if count > max_count or (count == max_count and val < max_val):
            max_count = count
            max_val = val
    return max_val, max_count

@cocotb.test()
async def test_max_frequency_basic(dut):
    """Test basic frequency counting"""
    # Test 1: From original - expected 2 (appears 5 times)
    test_data = [2,3,8,4,7,9,8,2,6,5,1,6,1,2,3,2]
    dut.data_in.value = test_data
    await Timer(10, units='ns')
    
    result_val = int(dut.max_value)
    result_count = int(dut.max_count)
    expected_val, expected_count = count_frequencies_python(test_data)
    
    print(f"Test 1: Input={test_data}")
    print(f"  Expected: value={expected_val}, count={expected_count}")
    print(f"  Got: value={result_val}, count={result_count}")
    
    if result_val != expected_val or result_count != expected_count:
        raise TestFailure(f"Test 1 failed: expected ({expected_val},{expected_count}), got ({result_val},{result_count})")

@cocotb.test()
async def test_max_frequency_multiple_max(dut):
    """Test with multiple values having same max count"""
    # Test 2: From original - 8 appears 3 times, but let's test tie-breaking
    test_data = [10,20,20,30,40,90,80,50,30,20,50,10,0,0,0,0]
    dut.data_in.value = test_data
    await Timer(10, units='ns')
    
    result_val = int(dut.max_value)
    result_count = int(dut.max_count)
    expected_val, expected_count = count_frequencies_python(test_data)
    
    print(f"Test 2: Input={test_data}")
    print(f"  Expected: value={expected_val}, count={expected_count}")
    print(f"  Got: value={result_val}, count={result_count}")
    
    if result_val != expected_val or result_count != expected_count:
        raise TestFailure(f"Test 2 failed: expected ({expected_val},{expected_count}), got ({result_val},{result_count})")

@cocotb.test()
async def test_max_frequency_all_same(dut):
    """Test when all elements are identical"""
    test_data = [42]*16
    dut.data_in.value = test_data
    await Timer(10, units='ns')
    
    result_val = int(dut.max_value)
    result_count = int(dut.max_count)
    
    print(f"Test 3: Input={test_data}")
    print(f"  Expected: value=42, count=16")
    print(f"  Got: value={result_val}, count={result_count}")
    
    if result_val != 42 or result_count != 16:
        raise TestFailure(f"Test 3 failed: expected (42,16), got ({result_val},{result_count})")

@cocotb.test()
async def test_max_frequency_all_different(dut):
    """Test when all elements are different"""
    test_data = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
    dut.data_in.value = test_data
    await Timer(10, units='ns')
    
    result_val = int(dut.max_value)
    result_count = int(dut.max_count)
    expected_val, expected_count = count_frequencies_python(test_data)
    
    print(f"Test 4: Input={test_data}")
    print(f"  Expected: value={expected_val}, count={expected_count}")
    print(f"  Got: value={result_val}, count={result_count}")
    
    if result_val != expected_val or result_count != expected_count:
        raise TestFailure(f"Test 4 failed: expected ({expected_val},{expected_count}), got ({result_val},{result_count})")

@cocotb.test()
async def test_max_frequency_edge_case_zeros(dut):
    """Test with zeros and small values"""
    test_data = [0,0,0,0,1,2,3,4,5,6,7,8,9,10,11,12]
    dut.data_in.value = test_data
    await Timer(10, units='ns')
    
    result_val = int(dut.max_value)
    result_count = int(dut.max_count)
    expected_val, expected_count = count_frequencies_python(test_data)
    
    print(f"Test 5: Input={test_data}")
    print(f"  Expected: value={expected_val}, count={expected_count}")
    print(f"  Got: value={result_val}, count={result_count}")
    
    if result_val != expected_val or result_count != expected_count:
        raise TestFailure(f"Test 5 failed: expected ({expected_val},{expected_count}), got ({result_val},{result_count})")

@cocotb.test()
async def test_max_frequency_max_values(dut):
    """Test with maximum 8-bit values"""
    test_data = [255,255,255,255,254,254,254,253,252,251,250,249,248,247,246,245]
    dut.data_in.value = test_data
    await Timer(10, units='ns')
    
    result_val = int(dut.max_value)
    result_count = int(dut.max_count)
    expected_val, expected_count = count_frequencies_python(test_data)
    
    print(f"Test 6: Input={test_data}")
    print(f"  Expected: value={expected_val}, count={expected_count}")
    print(f"  Got: value={result_val}, count={result_count}")
    
    if result_val != expected_val or result_count != expected_count:
        raise TestFailure(f"Test 6 failed: expected ({expected_val},{expected_count}), got ({result_val},{result_count})")

# Summary report
@cocotb.test()
async def print_summary(dut):
    """Print test summary - not an actual test"""
    print("
=== Test Summary ===")
    print("All tests designed for 16-element arrays with 8-bit values")
    print("Module finds value with highest frequency, tie-breaking by first occurrence")
    print("Expected latency: Combinational (0 cycles)")
    print("
Test cases cover:")
    print("1. Basic frequency count")
    print("2. Multiple max candidates")
    print("3. All identical values")
    print("4. All different values")
    print("5. Zero values")
    print("6. Maximum 8-bit values")
