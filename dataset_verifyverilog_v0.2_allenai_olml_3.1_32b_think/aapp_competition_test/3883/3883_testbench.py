import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import math

def to_q16_16(value):
    """Convert float to Q16.16 fixed-point"""
    return int(value * 65536)

def from_q16_16(value):
    """Convert Q16.16 to float"""
    return value / 65536.0

async def reset_dut(dut):
    """Reset the DUT"""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a_scaled.value = 0
    dut.b_scaled.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_polyline_basic(dut):
    """Test basic cases"""
    # Generate clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Test case 1: a=3, b=1 -> x=1.0
    # Scale: a_scaled = 3 * 256 = 768, b_scaled = 1 * 256 = 256
    dut.a_scaled.value = 768
    dut.b_scaled.value = 256
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 20 cycles)
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test case 1: Did not complete in time")
    
    if dut.no_solution.value == 1:
        raise TestFailure("Test case 1: Incorrectly reported no solution")
    
    result = from_q16_16(dut.result_x.value)
    expected = 1.0
    error = abs(result - expected)
    
    if error > 0.001:
        raise TestFailure(f"Test case 1: Expected {expected}, got {result}")
    
    print(f"Test 1 passed: a=3, b=1 -> x={result:.6f} (expected {expected})")
    
    await reset_dut(dut)
    
    # Test case 2: a=1, b=3 -> no solution
    # Scale: a_scaled = 1 * 256 = 256, b_scaled = 3 * 256 = 768
    dut.a_scaled.value = 256
    dut.b_scaled.value = 768
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test case 2: Did not complete in time")
    
    if dut.no_solution.value != 1:
        raise TestFailure(f"Test case 2: Should be no solution, got {from_q16_16(dut.result_x.value)}")
    
    print(f"Test 2 passed: a=1, b=3 -> no solution")
    
    await reset_dut(dut)
    
    # Test case 3: a=4, b=1 -> x=1.25
    # Scale: a_scaled = 4 * 256 = 1024, b_scaled = 1 * 256 = 256
    dut.a_scaled.value = 1024
    dut.b_scaled.value = 256
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test case 3: Did not complete in time")
    
    if dut.no_solution.value == 1:
        raise TestFailure("Test case 3: Incorrectly reported no solution")
    
    result = from_q16_16(dut.result_x.value)
    expected = 1.25
    error = abs(result - expected)
    
    if error > 0.001:
        raise TestFailure(f"Test case 3: Expected {expected}, got {result}")
    
    print(f"Test 3 passed: a=4, b=1 -> x={result:.6f} (expected {expected})")
    
    await reset_dut(dut)
    
    # Test case 4: a=11, b=5 -> x=8.0
    # Scale: a_scaled = 11 * 256 = 2816, b_scaled = 5 * 256 = 1280
    dut.a_scaled.value = 2816
    dut.b_scaled.value = 1280
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test case 4: Did not complete in time")
    
    if dut.no_solution.value == 1:
        raise TestFailure("Test case 4: Incorrectly reported no solution")
    
    result = from_q16_16(dut.result_x.value)
    expected = 8.0
    error = abs(result - expected)
    
    if error > 0.01:
        raise TestFailure(f"Test case 4: Expected {expected}, got {result}")
    
    print(f"Test 4 passed: a=11, b=5 -> x={result:.6f} (expected {expected})")
    
    await reset_dut(dut)
    
    # Test case 5: a=30, b=5 -> x≈5.833
    # Scale: a_scaled = 30 * 256 = 7680, b_scaled = 5 * 256 = 1280
    dut.a_scaled.value = 7680
    dut.b_scaled.value = 1280
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test case 5: Did not complete in time")
    
    if dut.no_solution.value == 1:
        raise TestFailure("Test case 5: Incorrectly reported no solution")
    
    result = from_q16_16(dut.result_x.value)
    expected = 30.0 / (2 * math.floor((30 + 5) / (2 * 5)))
    error = abs(result - expected)
    
    if error > 0.01:
        raise TestFailure(f"Test case 5: Expected {expected:.6f}, got {result:.6f}")
    
    print(f"Test 5 passed: a=30, b=5 -> x={result:.6f} (expected {expected:.6f})")
    
    print("
All 5 tests passed!")
