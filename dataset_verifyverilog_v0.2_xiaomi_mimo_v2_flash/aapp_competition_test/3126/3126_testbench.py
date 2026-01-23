import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def calculate_min_jumps_simple(pos, target):
    """Simplified greedy calculation for single frog"""
    dist = abs(pos - target)
    if dist == 0:
        return 0
    
    # Find minimum k where sum(1..k) >= dist
    k = 0
    total = 0
    while total < dist:
        k += 1
        total += k
    
    # Check if we need more jumps to match parity
    # For simplification, we check up to k+3
    for extra in range(4):
        test_k = k + extra
        test_sum = test_k * (test_k + 1) // 2
        if test_sum >= dist and (test_sum - dist) % 2 == 0:
            return test_k
    
    return k

def solve_batch(frogs, target):
    """Calculate total jumps for all frogs"""
    return sum(calculate_min_jumps_simple(p, target) for p in frogs)

@cocotb.test()
async def test_frog_dance_basic(dut):
    """Test basic frog dance functionality"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_frogs.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("Test 1: Single frog at 0, target 1")
    dut.frog_positions[0].value = 0
    dut.num_frogs.value = 1
    dut.target_pos.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result = int(dut.total_jumps.value)
    expected = solve_batch([0], 1)
    print(f"Result: {result}, Expected: {expected}")
    assert result == expected, f"Test 1 failed: {result} != {expected}"
    
    print("
Test 2: Three frogs, target 1")
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.frog_positions[0].value = 2
    dut.frog_positions[1].value = 6
    dut.frog_positions[2].value = 6
    dut.num_frogs.value = 3
    dut.target_pos.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result = int(dut.total_jumps.value)
    expected = solve_batch([2, 6, 6], 1)
    print(f"Result: {result}, Expected: {expected}")
    assert result == expected, f"Test 2 failed: {result} != {expected}"
    
    print("
Test 3: No frogs, target 3")
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_frogs.value = 0
    dut.target_pos.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result = int(dut.total_jumps.value)
    expected = 0
    print(f"Result: {result}, Expected: {expected}")
    assert result == expected, f"Test 3 failed: {result} != {expected}"
    
    print("
Test 4: Multiple positions")
    test_cases = [
        ([0], 0, 0),
        ([0], 1, 1),
        ([0], 2, 3),
        ([0], 3, 2),
        ([0], 4, 3),
        ([0], 5, 5),
        ([0], 6, 3),
    ]
    
    for frogs, target, expected in test_cases:
        dut.rst_n.value = 0
        await Timer(10, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        for i, p in enumerate(frogs):
            dut.frog_positions[i].value = p
        dut.num_frogs.value = len(frogs)
        dut.target_pos.value = target
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        timeout = 0
        while not dut.done.value and timeout < 10000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        result = int(dut.total_jumps.value)
        print(f"Frogs {frogs}, Target {target}: Result {result}, Expected {expected}")
        assert result == expected, f"Failed: {result} != {expected}"
    
    print("
All tests passed!")

@cocotb.test()
async def test_frog_dance_stress(dut):
    """Stress test with varied inputs"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_vectors = [
        ([2, 6, 6], 2, 6),
        ([2, 6, 6], 3, 5),
        ([2, 6, 6], 4, 9),
        ([2, 6, 6], 5, 4),
        ([2, 6, 6], 6, 3),
        ([2, 6, 6], 7, 7),
        ([2, 6, 6], 8, 9),
        ([2, 6, 6], 9, 9),
        ([2, 6, 6], 10, 10),
    ]
    
    passed = 0
    total = len(test_vectors)
    
    for frogs, target, expected in test_vectors:
        dut.rst_n.value = 0
        await Timer(10, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        for i, p in enumerate(frogs):
            dut.frog_positions[i].value = p
        dut.num_frogs.value = len(frogs)
        dut.target_pos.value = target
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        timeout = 0
        while not dut.done.value and timeout < 10000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        result = int(dut.total_jumps.value)
        if result == expected:
            passed += 1
        else:
            print(f"FAIL: Frogs {frogs}, Target {target}: Got {result}, Expected {expected}")
    
    print(f"
Stress tests: {passed}/{total} passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
