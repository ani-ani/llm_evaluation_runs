import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def compute_max_f(arr):
    """Compute max f value using the algorithm from Python solutions"""
    if len(arr) < 2:
        return 0
    
    # Build difference array with alternating signs starting +
    diff1 = []
    for i in range(len(arr) - 1):
        diff = abs(arr[i] - arr[i+1])
        if i % 2 == 0:
            diff1.append(diff)
        else:
            diff1.append(-diff)
    
    # Build difference array with alternating signs starting -
    diff2 = []
    for i in range(len(arr) - 1):
        diff = abs(arr[i] - arr[i+1])
        if i % 2 == 0:
            diff2.append(-diff)
        else:
            diff2.append(diff)
    
    # Kadane's algorithm for both sequences
    def max_subarray_sum(d):
        max_ending = d[0]
        max_so_far = d[0]
        for i in range(1, len(d)):
            max_ending = max(d[i], max_ending + d[i])
            max_so_far = max(max_so_far, max_ending)
        return max_so_far
    
    return max(max_subarray_sum(diff1), max_subarray_sum(diff2))

@cocotb.test()
async def test_max_f_value(dut):
    """Test max_f_value module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.a[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled down to 8 elements max)
    test_cases = [
        ([1, 4, 2, 3, 1], 3),  # Original example 1
        ([1, 5, 4, 7], 6),     # Original example 2
        ([16, 14, 12, 10, 8, 100, 50, 0], 92),  # Large test case
        ([1, 1], 0),           # Edge case: equal elements
        ([0, 1, -1], 2),       # Negative values
        ([10000, 0, 0, 10000], 20000),  # Large numbers
        ([10000, 0, 1, 10000], 19999),  # Near equal
    ]
    
    passed = 0
    total = len(test_cases)
    
    for arr, expected in test_cases:
        n = len(arr)
        
        # Load inputs
        dut.n.value = n
        for i in range(8):
            if i < n:
                dut.a[i].value = arr[i]
            else:
                dut.a[i].value = 0
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 50:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 50:
            raise TestFailure(f"Timeout for arr={arr}")
        
        # Read result
        actual = int(dut.result.value)
        
        # Check
        if actual == expected:
            passed += 1
            print(f"PASS: arr={arr}, expected={expected}, got={actual}")
        else:
            print(f"FAIL: arr={arr}, expected={expected}, got={actual}")
        
        await RisingEdge(dut.clk)
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
