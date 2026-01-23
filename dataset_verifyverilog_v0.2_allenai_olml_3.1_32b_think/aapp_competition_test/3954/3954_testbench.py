import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def bubble_sort_signed(arr):
    """Sort array in ascending order"""
    arr = list(arr)
    n = len(arr)
    for i in range(n):
        for j in range(0, n-i-1):
            if arr[j] > arr[j+1]:
                arr[j], arr[j+1] = arr[j+1], arr[j]
    return arr

def bubble_sort_desc_signed(arr):
    """Sort array in descending order"""
    arr = list(arr)
    n = len(arr)
    for i in range(n):
        for j in range(0, n-i-1):
            if arr[j] < arr[j+1]:
                arr[j], arr[j+1] = arr[j+1], arr[j]
    return arr

def solve_max_swap_subarray(a, k):
    """Reference Python implementation for verification"""
    n = len(a)
    best = -999999
    
    for l in range(n):
        for r in range(l, n):
            # Get inner elements
            inner = a[l:r+1]
            # Get outer elements
            outer = a[:l] + a[r+1:]
            
            # Sort inner ascending
            inner_sorted = bubble_sort_signed(inner)
            # Sort outer descending
            outer_sorted = bubble_sort_desc_signed(outer)
            
            current_sum = sum(inner)
            
            # Perform up to k swaps
            for i in range(min(k, len(inner_sorted), len(outer_sorted))):
                if outer_sorted[i] > inner_sorted[i]:
                    current_sum += outer_sorted[i] - inner_sorted[i]
                else:
                    break
            
            if current_sum > best:
                best = current_sum
    
    return best

@cocotb.test()
async def test_max_swap_subarray(dut):
    """Test max_swap_subarray module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k_in.value = 0
    dut.a_0.value = 0
    dut.a_1.value = 0
    dut.a_2.value = 0
    dut.a_3.value = 0
    dut.a_4.value = 0
    dut.a_5.value = 0
    dut.a_6.value = 0
    dut.a_7.value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
--- Testing max_swap_subarray module ---")
    
    # Test Case 1: Example 1 (adapted to N=8)
    # Original: [10, -1, 2, 2, 2, 2, 2, 2, -1, 10], k=2
    # Adapted: Remove two elements to fit N=8, let's try [10, -1, 2, 2, 2, 2, 2, -1]
    # Let's test [10, -1, 2, 2, 2, 2, 2, 10] to get closer to 32
    # Subarray [1, 7] = [-1, 2, 2, 2, 2, 2, 10], sum=17
    # Inner: [-1, 2, 2, 2, 2, 2, 10] -> sorted: [-1, 2, 2, 2, 2, 2, 10]
    # Outer: [10] -> sorted desc: [10]
    # Swap 1: 10 > -1, swap -> sum = 17 - (-1) + 10 = 28 (wait, diff is 11)
    # Actually: inner[0] becomes 10, sum becomes 17 - (-1) + 10 = 28
    
    # Let's use test case: [10, -1, 2, 2, 2, 2, 2, 10], k=2
    # Best sum: subarray [1, 7]: 17
    # Swap -1 with 10: sum becomes 28. 
    # Outer is just [10]. Only 1 swap possible.
    # Actually original problem: outer is [10, 10], inner is [-1, 2, 2, 2, 2, 2, 2]
    # Sum inner = 11. Swap -1 with 10 (sum 21), swap 2 with 10 (sum 29).
    # Original answer is 32 (sum of all positives).
    
    # Let's test: Array [10, 10, -1, 2, 2, 2, 2, 2], k=2
    # Best subarray l=0, r=7: sum = 29
    # Inner: [10, 10, -1, 2, 2, 2, 2, 2]
    # Outer: []
    # Sum = 29.
    
    # Test Case A: All positive
    a_test = [10, 10, 10, 10, 2, 2, 2, 2]
    k_test = 2
    expected = solve_max_swap_subarray(a_test, k_test)
    
    dut.a_0.value = a_test[0]
    dut.a_1.value = a_test[1]
    dut.a_2.value = a_test[2]
    dut.a_3.value = a_test[3]
    dut.a_4.value = a_test[4]
    dut.a_5.value = a_test[5]
    dut.a_6.value = a_test[6]
    dut.a_7.value = a_test[7]
    dut.k_in.value = k_test
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max ~50 cycles)
    cycles = 0
    while not dut.done.value and cycles < 100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    dut._log.info(f"Test A: Array={a_test}, k={k_test}")
    dut._log.info(f"Expected: {expected}, Got: {dut.result.value}")
    
    if dut.result.value != expected:
        raise TestFailure(f"Test A failed: Expected {expected}, got {int(dut.result.value)}")
    
    print("Test A passed")
    
    # Test Case B: Mix of positive and negative (Example 2)
    # All -1, N=8, k=2
    a_test = [-1, -1, -1, -1, -1, -1, -1, -1]
    k_test = 2
    expected = solve_max_swap_subarray(a_test, k_test)
    
    dut.a_0.value = a_test[0]
    dut.a_1.value = a_test[1]
    dut.a_2.value = a_test[2]
    dut.a_3.value = a_test[3]
    dut.a_4.value = a_test[4]
    dut.a_5.value = a_test[5]
    dut.a_6.value = a_test[6]
    dut.a_7.value = a_test[7]
    dut.k_in.value = k_test
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    dut._log.info(f"Test B: Array={a_test}, k={k_test}")
    dut._log.info(f"Expected: {expected}, Got: {dut.result.value}")
    
    if dut.result.value != expected:
        raise TestFailure(f"Test B failed: Expected {expected}, got {int(dut.result.value)}")
    
    print("Test B passed")
    
    # Test Case C: Positive subarray with negative neighbors
    # Array: [5, 1, 2, 3, 4, 5, -10, -20], k=3
    # Best might be [1,2,3,4,5] sum=15, or [0,1,2,3,4,5] sum=20 (with 5 already there)
    # Let's see if it can swap -10 and -20 out from a larger subarray
    # Subarray [0, 6]: [5,1,2,3,4,5,-10] sum=10. Inner sorted: [-10,1,2,3,4,5,5]. 
    # Outer: [-20]. Swap -10 with -20? No, -20 < -10. 
    # Actually we want to swap small numbers with large ones.
    # Let's try: [10, 1, 1, 1, 1, 1, -5, -5], k=2
    # Subarray [0, 5]: sum=15. Inner=[10,1,1,1,1,1], Outer=[-5,-5]. No swaps possible.
    # Subarray [1, 5]: sum=5. Inner=[1,1,1,1,1]. Outer=[10,-5,-5]. Swap 1 with 10 -> sum=14.
    a_test = [10, 1, 1, 1, 1, 1, -5, -5]
    k_test = 2
    expected = solve_max_swap_subarray(a_test, k_test)
    
    dut.a_0.value = a_test[0]
    dut.a_1.value = a_test[1]
    dut.a_2.value = a_test[2]
    dut.a_3.value = a_test[3]
    dut.a_4.value = a_test[4]
    dut.a_5.value = a_test[5]
    dut.a_6.value = a_test[6]
    dut.a_7.value = a_test[7]
    dut.k_in.value = k_test
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    dut._log.info(f"Test C: Array={a_test}, k={k_test}")
    dut._log.info(f"Expected: {expected}, Got: {dut.result.value}")
    
    if dut.result.value != expected:
        raise TestFailure(f"Test C failed: Expected {expected}, got {int(dut.result.value)}")
    
    print("Test C passed")
    
    # Test Case D: Single element array
    a_test = [5, 0, 0, 0, 0, 0, 0, 0]
    k_test = 2
    expected = solve_max_swap_subarray(a_test, k_test)
    
    dut.a_0.value = a_test[0]
    dut.a_1.value = a_test[1]
    dut.a_2.value = a_test[2]
    dut.a_3.value = a_test[3]
    dut.a_4.value = a_test[4]
    dut.a_5.value = a_test[5]
    dut.a_6.value = a_test[6]
    dut.a_7.value = a_test[7]
    dut.k_in.value = k_test
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    dut._log.info(f"Test D: Array={a_test}, k={k_test}")
    dut._log.info(f"Expected: {expected}, Got: {dut.result.value}")
    
    if dut.result.value != expected:
        raise TestFailure(f"Test D failed: Expected {expected}, got {int(dut.result.value)}")
    
    print("Test D passed")
    
    # Test Case E: Array where swap makes sense (original problem type)
    # [10, -1, 2, 2, 2, 2, 2, 10], k=1
    # Subarray [0, 7]: sum = 29. Inner: [10, -1, 2, 2, 2, 2, 2, 10]. 
    # Wait, we are limited to N=8. 
    # Let's use: [10, -1, 2, 2, 2, 2, 2, 5], k=1
    # Best: [0, 7] sum = 24. Inner sorted: [-1, 2, 2, 2, 2, 2, 5, 10].
    # Outer: []. 
    # Actually, if we take subarray [1, 7]: sum = 14. Inner: [-1, 2, 2, 2, 2, 2, 5].
    # Outer: [10]. Swap -1 with 10. Sum becomes 25.
    a_test = [10, -1, 2, 2, 2, 2, 2, 5]
    k_test = 1
    expected = solve_max_swap_subarray(a_test, k_test)
    
    dut.a_0.value = a_test[0]
    dut.a_1.value = a_test[1]
    dut.a_2.value = a_test[2]
    dut.a_3.value = a_test[3]
    dut.a_4.value = a_test[4]
    dut.a_5.value = a_test[5]
    dut.a_6.value = a_test[6]
    dut.a_7.value = a_test[7]
    dut.k_in.value = k_test
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    dut._log.info(f"Test E: Array={a_test}, k={k_test}")
    dut._log.info(f"Expected: {expected}, Got: {dut.result.value}")
    
    if dut.result.value != expected:
        raise TestFailure(f"Test E failed: Expected {expected}, got {int(dut.result.value)}")
    
    print("Test E passed")
    
    # Summary
    total_tests = 5
    print(f"
{total_tests}/{total_tests} tests passed")
