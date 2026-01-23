import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def int_to_decimal_digits(n):
    """Convert integer to list of decimal digits (positive only)"""
    if n == 0:
        return [0]
    digits = []
    while n > 0:
        digits.append(n % 10)
        n //= 10
    return digits[::-1]

def multiple_to_single_py(L):
    """Reference Python implementation"""
    x = int("".join(map(str, L)))
    return x

@cocotb.test()
async def test_multiple_to_single(dut):
    """Test multiple_to_single module with various inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_1.value = 0
    dut.num_2.value = 0
    dut.num_3.value = 0
    dut.num_4.value = 0
    dut.num_5.value = 0
    dut.num_6.value = 0
    dut.count.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [11, 33, 50] -> 113350
    dut._log.info("Test 1: [11, 33, 50]")
    dut.num_1.value = 11
    dut.num_2.value = 33
    dut.num_3.value = 50
    dut.count.value = 3
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 200:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    expected = multiple_to_single_py([11, 33, 50])
    actual = int(dut.result.value)
    
    if actual != expected:
        raise TestFailure(f"Test 1 failed: expected {expected}, got {actual}")
    
    dut._log.info(f"Test 1 passed: result = {actual}")
    
    # Test case 2: [-1, 2, 3, 4, 5, 6] -> -123456
    await RisingEdge(dut.clk)
    dut.num_1.value = -1 & 0xFFFFFFFF  # 32-bit representation
    dut.num_2.value = 2
    dut.num_3.value = 3
    dut.num_4.value = 4
    dut.num_5.value = 5
    dut.num_6.value = 6
    dut.count.value = 6
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 200:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    expected = multiple_to_single_py([-1, 2, 3, 4, 5, 6])
    actual = int(dut.result.value)
    # Sign extend if negative
    if actual >= (1 << 63):
        actual = actual - (1 << 64)
    
    if actual != expected:
        raise TestFailure(f"Test 2 failed: expected {expected}, got {actual}")
    
    dut._log.info(f"Test 2 passed: result = {actual}")
    
    # Test case 3: [10, 15, 20, 25] -> 10152025
    await RisingEdge(dut.clk)
    dut.num_1.value = 10
    dut.num_2.value = 15
    dut.num_3.value = 20
    dut.num_4.value = 25
    dut.count.value = 4
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 200:
        raise TestFailure("Test 3: Timeout waiting for done")
    
    expected = multiple_to_single_py([10, 15, 20, 25])
    actual = int(dut.result.value)
    
    if actual != expected:
        raise TestFailure(f"Test 3 failed: expected {expected}, got {actual}")
    
    dut._log.info(f"Test 3 passed: result = {actual}")
    
    # Additional edge cases
    # Test case 4: Single positive number
    await RisingEdge(dut.clk)
    dut.num_1.value = 42
    dut.count.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    expected = multiple_to_single_py([42])
    actual = int(dut.result.value)
    assert actual == expected, f"Test 4 failed: expected {expected}, got {actual}"
    dut._log.info(f"Test 4 passed: result = {actual}")
    
    # Test case 5: Two negatives
    await RisingEdge(dut.clk)
    dut.num_1.value = -5 & 0xFFFFFFFF
    dut.num_2.value = -7 & 0xFFFFFFFF
    dut.count.value = 2
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    expected = multiple_to_single_py([-5, -7])
    actual = int(dut.result.value)
    if actual >= (1 << 63):
        actual = actual - (1 << 64)
    assert actual == expected, f"Test 5 failed: expected {expected}, got {actual}"
    dut._log.info(f"Test 5 passed: result = {actual}")
    
    dut._log.info("All 5 tests passed!")