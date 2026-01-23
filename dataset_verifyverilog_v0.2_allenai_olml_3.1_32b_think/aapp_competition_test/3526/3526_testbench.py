import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_true_false_hints(dut):
    """Test true_false_hints module with various hint configurations"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    for i in range(20):
        dut.hint_l[i].value = 0
        dut.hint_r[i].value = 0
        dut.hint_type[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Sample from problem (adapted to n=5)
    # 5 2
    # 2 4 same
    # 3 5 same
    # Expected: 4 valid sequences
    
    dut.n.value = 5
    dut.m.value = 2
    dut.hint_l[0].value = 2
    dut.hint_r[0].value = 4
    dut.hint_type[0].value = 0  # same
    dut.hint_l[1].value = 3
    dut.hint_r[1].value = 5
    dut.hint_type[1].value = 0  # same
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 2000:
        raise TestFailure("Test 1: Timeout waiting for completion")
    
    if dut.error.value:
        raise TestFailure("Test 1: Unexpected error flag")
    
    result1 = int(dut.result.value)
    expected1 = 4
    if result1 != expected1:
        raise TestFailure(f"Test 1: Expected {expected1}, got {result1}")
    print(f"Test 1 passed: {result1} == {expected1}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 2: Conflict case (adapted)
    # 5 3
    # 1 3 same
    # 2 5 same
    # 1 5 different
    # Expected: 0 (conflict)
    
    dut.n.value = 5
    dut.m.value = 3
    dut.hint_l[0].value = 1
    dut.hint_r[0].value = 3
    dut.hint_type[0].value = 0  # same
    dut.hint_l[1].value = 2
    dut.hint_r[1].value = 5
    dut.hint_type[1].value = 0  # same
    dut.hint_l[2].value = 1
    dut.hint_r[2].value = 5
    dut.hint_type[2].value = 1  # different
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 2000:
        raise TestFailure("Test 2: Timeout waiting for completion")
    
    if dut.error.value:
        print("Test 2 passed: Conflict detected as expected")
    else:
        result2 = int(dut.result.value)
        if result2 != 0:
            raise TestFailure(f"Test 2: Expected 0 or error flag, got result={result2}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 3: All same hint on n=3
    # 3 1
    # 1 3 same
    # Expected: 2 (all 0s or all 1s)
    
    dut.n.value = 3
    dut.m.value = 1
    dut.hint_l[0].value = 1
    dut.hint_r[0].value = 3
    dut.hint_type[0].value = 0  # same
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 2000:
        raise TestFailure("Test 3: Timeout")
    
    if dut.error.value:
        raise TestFailure("Test 3: Unexpected error")
    
    result3 = int(dut.result.value)
    expected3 = 2
    if result3 != expected3:
        raise TestFailure(f"Test 3: Expected {expected3}, got {result3}")
    print(f"Test 3 passed: {result3} == {expected3}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 4: All different hints (n=2)
    # 2 1
    # 1 2 different
    # Expected: 2 (01 or 10)
    
    dut.n.value = 2
    dut.m.value = 1
    dut.hint_l[0].value = 1
    dut.hint_r[0].value = 2
    dut.hint_type[0].value = 1  # different
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 2000:
        raise TestFailure("Test 4: Timeout")
    
    if dut.error.value:
        raise TestFailure("Test 4: Unexpected error")
    
    result4 = int(dut.result.value)
    expected4 = 2
    if result4 != expected4:
        raise TestFailure(f"Test 4: Expected {expected4}, got {result4}")
    print(f"Test 4 passed: {result4} == {expected4}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 5: Single problem, no hints
    # 1 0
    # Expected: 2 (0 or 1)
    
    dut.n.value = 1
    dut.m.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 2000:
        raise TestFailure("Test 5: Timeout")
    
    if dut.error.value:
        raise TestFailure("Test 5: Unexpected error")
    
    result5 = int(dut.result.value)
    expected5 = 2
    if result5 != expected5:
        raise TestFailure(f"Test 5: Expected {expected5}, got {result5}")
    print(f"Test 5 passed: {result5} == {expected5}")
    
    print("
Test Summary: 5/5 tests passed")
