import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def popcount(n):
    """Count number of 1s in binary representation."""
    count = 0
    while n:
        count += n & 1
        n >>= 1
    return count

def sort_python(arr):
    """Python reference implementation."""
    if not arr:
        return []
    # Filter out negative numbers per problem spec (non-negative only)
    filtered = [x for x in arr if x >= 0]
    # Sort by popcount first, then by value
    return sorted(filtered, key=lambda x: (popcount(x), x))

def adapt_test_case(arr):
    """Adapt test case for HDL: filter negatives, cap to 8 elements."""
    # Remove negative numbers
    filtered = [x for x in arr if x >= 0]
    # Limit to 8 elements
    limited = filtered[:8]
    return limited

def compute_expected(test_case):
    """Compute expected result using Python reference."""
    return sort_python(test_case)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sort_array(dut):
    """Test sort_array module with various test cases."""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    test_cases = [
        ([1, 5, 2, 3, 4], [1, 2, 4, 3, 5]),  # Basic test
        ([1, 0, 2, 3, 4], [0, 1, 2, 4, 3]),  # With zero
        ([2, 5, 77, 4, 5, 3, 5, 7, 2, 3, 4], [2, 2, 4, 4, 3, 3, 5, 5, 5, 7, 77]),  # Many elements
        ([3, 6, 44, 12, 32, 5], [32, 3, 5, 6, 12, 44]),  # Various popcounts
        ([2, 4, 8, 16, 32], [2, 4, 8, 16, 32]),  # Already sorted (powers of 2)
        ([15, 7, 3, 1], [1, 3, 7, 15]),  # Reverse popcount order
        ([10, 5, 3, 9], [5, 3, 10, 9]),  # Ties in popcount
        ([0, 0, 0, 0], [0, 0, 0, 0]),  # All zeros
        ([1], [1]),  # Single element
        ([-2, -3, -4], []),  # All negatives (empty result)
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases...")
    
    for i, (input_arr, expected_orig) in enumerate(test_cases):
        dut._log.info(f"\nTest case {i+1}: input={input_arr}")
        
        # Adapt test case
        adapted_input = adapt_test_case(input_arr)
        expected = compute_expected(adapted_input)
        
        dut._log.info(f"  Adapted input: {adapted_input}")
        dut._log.info(f"  Expected: {expected}")
        
        # Load inputs
        dut.len.value = len(adapted_input)
        for j in range(8):
            if j < len(adapted_input):
                dut.arr[j].value = adapted_input[j]
            else:
                dut.arr[j].value = 0
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with cycle timeout
        MAX_CYCLES = 2000
        done_found = False
        for cycle in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if not is_value_defined(dut.done.value):
                continue
            if dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test {i+1}: Timeout after {MAX_CYCLES} cycles, done never went high")
        
        # Read output
        result = []
        for j in range(8):
            if not is_value_defined(dut.result[j].value):
                raise TestFailure(f"Test {i+1}: result[{j}] is undefined (X/Z)")
            val = int(dut.result[j].value)
            if j < len(adapted_input):
                result.append(val)
        
        dut._log.info(f"  Got: {result}")
        
        if result == expected:
            dut._log.info(f"  [PASS]")
            passed += 1
        else:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        # Small delay between tests
        await Timer(100, units="ns")
    
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
