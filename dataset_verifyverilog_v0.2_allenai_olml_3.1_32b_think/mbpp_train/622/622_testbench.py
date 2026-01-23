import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def to_q1616(value):
    """Convert decimal to Q16.16 format"""
    return int(value * 65536)

def from_q1616(value):
    """Convert Q16.16 to decimal"""
    return value / 65536.0

async def reset_dut(dut):
    """Reset the DUT"""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.arr1[i].value = 0
        dut.arr2[i].value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_median_basic(dut):
    """Test basic median calculation"""
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Test 1: [1, 12, 15, 26, 38], [2, 13, 17, 30, 45] -> median = 16.0
    arr1 = [1, 12, 15, 26, 38]
    arr2 = [2, 13, 17, 30, 45]
    n = 5
    expected = 16.0
    
    dut.n.value = n
    for i in range(8):
        dut.arr1[i].value = arr1[i] if i < n else 0
        dut.arr2[i].value = arr2[i] if i < n else 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = from_q1616(dut.result.value)
    assert abs(result - expected) < 0.01, f"Test 1 failed: expected {expected}, got {result}"
    print(f"Test 1 passed: {result}")

@cocotb.test()
async def test_median_basic2(dut):
    """Test second basic case"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Test 2: [2, 4, 8, 9], [7, 13, 19, 28] -> median = 8.5
    arr1 = [2, 4, 8, 9]
    arr2 = [7, 13, 19, 28]
    n = 4
    expected = 8.5
    
    dut.n.value = n
    for i in range(8):
        dut.arr1[i].value = arr1[i] if i < n else 0
        dut.arr2[i].value = arr2[i] if i < n else 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = from_q1616(dut.result.value)
    assert abs(result - expected) < 0.01, f"Test 2 failed: expected {expected}, got {result}"
    print(f"Test 2 passed: {result}")

@cocotb.test()
async def test_median_basic3(dut):
    """Test third basic case"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Test 3: [3, 6, 14, 23, 36, 42], [2, 18, 27, 39, 49, 55] -> median = 25.0
    arr1 = [3, 6, 14, 23, 36, 42]
    arr2 = [2, 18, 27, 39, 49, 55]
    n = 6
    expected = 25.0
    
    dut.n.value = n
    for i in range(8):
        dut.arr1[i].value = arr1[i] if i < n else 0
        dut.arr2[i].value = arr2[i] if i < n else 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = from_q1616(dut.result.value)
    assert abs(result - expected) < 0.01, f"Test 3 failed: expected {expected}, got {result}"
    print(f"Test 3 passed: {result}")

@cocotb.test()
async def test_median_small_n(dut):
    """Test with n=1 (minimum size)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # n=1: [5], [7] -> median = (5+7)/2 = 6.0
    arr1 = [5]
    arr2 = [7]
    n = 1
    expected = 6.0
    
    dut.n.value = n
    for i in range(8):
        dut.arr1[i].value = arr1[i] if i < n else 0
        dut.arr2[i].value = arr2[i] if i < n else 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = from_q1616(dut.result.value)
    assert abs(result - expected) < 0.01, f"Test n=1 failed: expected {expected}, got {result}"
    print(f"Test n=1 passed: {result}")

@cocotb.test()
async def test_median_max_n(dut):
    """Test with n=8 (maximum size)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # n=8: [1,3,5,7,9,11,13,15], [2,4,6,8,10,12,14,16] -> median = (8+9)/2 = 8.5
    arr1 = [1, 3, 5, 7, 9, 11, 13, 15]
    arr2 = [2, 4, 6, 8, 10, 12, 14, 16]
    n = 8
    expected = 8.5
    
    dut.n.value = n
    for i in range(8):
        dut.arr1[i].value = arr1[i]
        dut.arr2[i].value = arr2[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = from_q1616(dut.result.value)
    assert abs(result - expected) < 0.01, f"Test n=8 failed: expected {expected}, got {result}"
    print(f"Test n=8 passed: {result}")

@cocotb.test()
async def test_median_consecutive(dut):
    """Test multiple consecutive operations"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    test_cases = [
        ([1, 2], [3, 4], 2, 2.5),
        ([10, 20], [15, 25], 2, 17.5),
        ([1, 2, 3], [4, 5, 6], 3, 3.5)
    ]
    
    for idx, (a1, a2, n, expected) in enumerate(test_cases):
        dut.n.value = n
        for i in range(8):
            dut.arr1[i].value = a1[i] if i < n else 0
            dut.arr2[i].value = a2[i] if i < n else 0
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        result = from_q1616(dut.result.value)
        assert abs(result - expected) < 0.01, f"Consecutive test {idx+1} failed: expected {expected}, got {result}"
        print(f"Consecutive test {idx+1} passed: {result}")
    
    print(f"All tests completed!")