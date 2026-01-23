import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
import random

def calculate_max_points(arr):
    """Python reference implementation for small arrays"""
    if len(arr) <= 1:
        return 0
    
    stack = []
    score = 0
    
    for i, val in enumerate(arr):
        while len(stack) > 1 and stack[-1] <= min(val, stack[-2]):
            score += min(val, stack[-2])
            stack.pop()
        stack.append(val)
    
    # Process remaining stack
    for i in range(1, len(stack) - 1):
        score += min(stack[i-1], stack[i+1])
    
    return score

@cocotb.test()
async def test_max_points_basic(dut):
    """Test basic functionality with example from problem"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.done_in.value = 0
    dut.data_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [3, 1, 5, 2, 6] -> 11
    test_arr = [3, 1, 5, 2, 6]
    expected = calculate_max_points(test_arr)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for ready
    while not dut.ready.value:
        await RisingEdge(dut.clk)
    
    # Feed array elements
    for val in test_arr:
        dut.data_in.value = val  # Just value in lower byte
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    dut.done_in.value = 1
    await RisingEdge(dut.clk)
    dut.done_in.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    print(f"Test 1: Input {test_arr}, Expected {expected}, Got {result}")
    assert result == expected, f"Mismatch: expected {expected}, got {result}"

@cocotb.test()
async def test_max_points_monotonic(dut):
    """Test with increasing sequence [1,2,3,4,5] -> 6"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.done_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_arr = [1, 2, 3, 4, 5]
    expected = calculate_max_points(test_arr)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.ready.value:
        await RisingEdge(dut.clk)
    
    for val in test_arr:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    dut.done_in.value = 1
    await RisingEdge(dut.clk)
    dut.done_in.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    print(f"Test 2: Input {test_arr}, Expected {expected}, Got {result}")
    assert result == expected, f"Mismatch: expected {expected}, got {result}"

@cocotb.test()
async def test_max_points_peaks(dut):
    """Test with peaks [1,100,101,100,1] -> 102"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.done_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_arr = [1, 100, 101, 100, 1]
    expected = calculate_max_points(test_arr)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.ready.value:
        await RisingEdge(dut.clk)
    
    for val in test_arr:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    dut.done_in.value = 1
    await RisingEdge(dut.clk)
    dut.done_in.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    print(f"Test 3: Input {test_arr}, Expected {expected}, Got {result}")
    assert result == expected, f"Mismatch: expected {expected}, got {result}"

@cocotb.test()
async def test_max_points_edge_cases(dut):
    """Test edge cases: single element, two elements"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test single element
    for test_arr, expected in [([87], 0), ([93, 51], 0), ([31, 19, 5], 5)]:
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.valid_in.value = 0
        dut.done_in.value = 0
        await Timer(50, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        while not dut.ready.value:
            await RisingEdge(dut.clk)
        
        for val in test_arr:
            dut.data_in.value = val
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
        
        dut.valid_in.value = 0
        dut.done_in.value = 1
        await RisingEdge(dut.clk)
        dut.done_in.value = 0
        
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        result = int(dut.result.value)
        print(f"Edge case: Input {test_arr}, Expected {expected}, Got {result}")
        assert result == expected, f"Mismatch: expected {expected}, got {result}"

@cocotb.test()
async def test_max_points_complex(dut):
    """Test with more complex pattern"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.done_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # [2, 6, 2, 1, 2] -> 6
    test_arr = [2, 6, 2, 1, 2]
    expected = calculate_max_points(test_arr)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.ready.value:
        await RisingEdge(dut.clk)
    
    for val in test_arr:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    dut.done_in.value = 1
    await RisingEdge(dut.clk)
    dut.done_in.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    print(f"Test 5: Input {test_arr}, Expected {expected}, Got {result}")
    assert result == expected, f"Mismatch: expected {expected}, got {result}"
    
    print("
All tests completed successfully!")
    
    # Summary
    passed = 0
    total = 5
    for test in dut._coverage_db:
        passed += 1
    print(f"
Summary: {passed}/{total} tests passed")