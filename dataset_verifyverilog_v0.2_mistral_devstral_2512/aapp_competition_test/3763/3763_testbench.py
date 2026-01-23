import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import math

@cocotb.test()
async def test_restaurant_visitor_expected(dut):
    """Test restaurant visitor expected value calculation"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.a_0.value = 0
    dut.a_1.value = 0
    dut.a_2.value = 0
    dut.a_3.value = 0
    dut.a_4.value = 0
    dut.a_5.value = 0
    dut.a_6.value = 0
    dut.a_7.value = 0
    dut.p.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=3, a=[1,2,3], p=3, expected=1.33333
    # Q16.16: 1.33333 * 65536 = 87381
    dut.n.value = 3
    dut.a_0.value = 1
    dut.a_1.value = 2
    dut.a_2.value = 3
    dut.p.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 5000 cycles for n=3)
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    result = dut.result.value.integer
    # Allow small error for floating point conversion
    expected = int(87381)  # 1.33333 * 65536
    if abs(result - expected) > 1000:
        raise TestFailure(f"Test 1: Result {result} != Expected {expected}")
    print(f"Test 1 passed: {result} (expected ~{expected})")
    
    await RisingEdge(dut.clk)
    await Timer(100, units='ns')
    
    # Test case 2: n=2, a=[1,3], p=3, expected=1.0
    # Q16.16: 1.0 * 65536 = 65536
    dut.n.value = 2
    dut.a_0.value = 1
    dut.a_1.value = 3
    dut.p.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    result = dut.result.value.integer
    expected = 65536  # 1.0 * 65536
    if abs(result - expected) > 1000:
        raise TestFailure(f"Test 2: Result {result} != Expected {expected}")
    print(f"Test 2 passed: {result} (expected {expected})")
    
    await RisingEdge(dut.clk)
    await Timer(100, units='ns')
    
    # Test case 3: n=2, a=[1,2], p=2, expected=1.0
    # Permutations: [1,2] -> 1 person (1<=2, 1+2=3>2)
    # [2,1] -> 1 person (2<=2, 2+1=3>2)
    # Sum = 2, /2 = 1.0
    dut.n.value = 2
    dut.a_0.value = 1
    dut.a_1.value = 2
    dut.p.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test 3: Timeout waiting for done")
    
    result = dut.result.value.integer
    expected = 65536  # 1.0 * 65536
    if abs(result - expected) > 1000:
        raise TestFailure(f"Test 3: Result {result} != Expected {expected}")
    print(f"Test 3 passed: {result} (expected {expected})")
    
    await RisingEdge(dut.clk)
    await Timer(100, units='ns')
    
    # Test case 4: n=3, a=[1,1,1], p=50, expected=3.0
    # All guests fit, 3 per permutation * 6 = 18, /6 = 3.0
    dut.n.value = 3
    dut.a_0.value = 1
    dut.a_1.value = 1
    dut.a_2.value = 1
    dut.p.value = 50
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test 4: Timeout waiting for done")
    
    result = dut.result.value.integer
    expected = 196608  # 3.0 * 65536
    if abs(result - expected) > 1000:
        raise TestFailure(f"Test 4: Result {result} != Expected {expected}")
    print(f"Test 4 passed: {result} (expected {expected})")
    
    # Summary
    print("
All tests passed!")
