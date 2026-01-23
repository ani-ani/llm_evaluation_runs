import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

MOD = 1000000007

def factorial(n):
    if n <= 1:
        return 1
    res = 1
    for i in range(2, n+1):
        res *= i
    return res

def nCr(n, r):
    if r < 0 or r > n:
        return 0
    return factorial(n) // (factorial(r) * factorial(n-r))

def python_max_subset_sum(arr, K):
    n = len(arr)
    # Generate all combinations of K elements
    from itertools import combinations
    total = 0
    for combo in combinations(arr, K):
        total += max(combo)
    return total % MOD

@cocotb.test()
async def test_max_subset_sum(dut):
    """Test max subset sum calculation"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.write_idx.value = 0
    dut.N.value = 0
    dut.K.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test Case 1: 5 3
    # Input: 2 4 2 3 4
    # Expected: 39
    dut._log.info("Test Case 1: N=5, K=3")
    arr1 = [2, 4, 2, 3, 4]
    
    # Load array values
    dut.N.value = 5
    dut.K.value = 3
    for i, val in enumerate(arr1):
        dut.data_in.value = val
        dut.write_idx.value = i
        await RisingEdge(dut.clk)
    
    # Fill remaining slots with 0
    for i in range(5, 16):
        dut.data_in.value = 0
        dut.write_idx.value = i
        await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 50000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 50000, "Timeout waiting for done"
    
    result1 = int(dut.result.value)
    expected1 = python_max_subset_sum(arr1, 3)
    dut._log.info(f"Result: {result1}, Expected: {expected1}")
    assert result1 == expected1, f"Test 1 failed: got {result1}, expected {expected1}"
    
    await Timer(100, units='ns')
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test Case 2: 5 1
    # Input: 1 0 1 1 1
    # Expected: 4
    dut._log.info("Test Case 2: N=5, K=1")
    arr2 = [1, 0, 1, 1, 1]
    
    dut.N.value = 5
    dut.K.value = 1
    for i, val in enumerate(arr2):
        dut.data_in.value = val
        dut.write_idx.value = i
        await RisingEdge(dut.clk)
    
    for i in range(5, 16):
        dut.data_in.value = 0
        dut.write_idx.value = i
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 50000, "Timeout waiting for done"
    
    result2 = int(dut.result.value)
    expected2 = python_max_subset_sum(arr2, 1)
    dut._log.info(f"Result: {result2}, Expected: {expected2}")
    assert result2 == expected2, f"Test 2 failed: got {result2}, expected {expected2}"
    
    await Timer(100, units='ns')
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test Case 3: 5 2
    # Input: 3 3 4 0 0
    # Expected: 31
    dut._log.info("Test Case 3: N=5, K=2")
    arr3 = [3, 3, 4, 0, 0]
    
    dut.N.value = 5
    dut.K.value = 2
    for i, val in enumerate(arr3):
        dut.data_in.value = val
        dut.write_idx.value = i
        await RisingEdge(dut.clk)
    
    for i in range(5, 16):
        dut.data_in.value = 0
        dut.write_idx.value = i
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 50000, "Timeout waiting for done"
    
    result3 = int(dut.result.value)
    expected3 = python_max_subset_sum(arr3, 2)
    dut._log.info(f"Result: {result3}, Expected: {expected3}")
    assert result3 == expected3, f"Test 3 failed: got {result3}, expected {expected3}"
    
    await Timer(100, units='ns')
    
    # Test Case 4: Edge case - all same values
    # N=3, K=2, arr=[5, 5, 5] -> sum=5+5+5=15
    dut._log.info("Test Case 4: Edge case all same")
    arr4 = [5, 5, 5]
    
    dut.N.value = 3
    dut.K.value = 2
    for i, val in enumerate(arr4):
        dut.data_in.value = val
        dut.write_idx.value = i
        await RisingEdge(dut.clk)
    
    for i in range(3, 16):
        dut.data_in.value = 0
        dut.write_idx.value = i
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 50000, "Timeout waiting for done"
    
    result4 = int(dut.result.value)
    expected4 = python_max_subset_sum(arr4, 2)
    dut._log.info(f"Result: {result4}, Expected: {expected4}")
    assert result4 == expected4, f"Test 4 failed: got {result4}, expected {expected4}"
    
    await Timer(100, units='ns')
    
    # Test Case 5: K=N
    # N=4, K=4, arr=[1, 2, 3, 4] -> only one combo, max=4
    dut._log.info("Test Case 5: K=N case")
    arr5 = [1, 2, 3, 4]
    
    dut.N.value = 4
    dut.K.value = 4
    for i, val in enumerate(arr5):
        dut.data_in.value = val
        dut.write_idx.value = i
        await RisingEdge(dut.clk)
    
    for i in range(4, 16):
        dut.data_in.value = 0
        dut.write_idx.value = i
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 50000, "Timeout waiting for done"
    
    result5 = int(dut.result.value)
    expected5 = python_max_subset_sum(arr5, 4)
    dut._log.info(f"Result: {result5}, Expected: {expected5}")
    assert result5 == expected5, f"Test 5 failed: got {result5}, expected {expected5}"
    
    # Summary
    total_tests = 5
    passed_tests = 0
    if result1 == expected1:
        passed_tests += 1
    if result2 == expected2:
        passed_tests += 1
    if result3 == expected3:
        passed_tests += 1
    if result4 == expected4:
        passed_tests += 1
    if result5 == expected5:
        passed_tests += 1
    
    dut._log.info(f"
SUMMARY: {passed_tests}/{total_tests} tests passed")
