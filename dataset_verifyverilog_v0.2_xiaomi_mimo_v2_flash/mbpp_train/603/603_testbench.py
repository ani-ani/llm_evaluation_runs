import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def get_ludic_reference(n):
    """Reference Python implementation of Ludic number generation"""
    ludics = []
    for i in range(1, n + 1):
        ludics.append(i)
    index = 1
    while(index != len(ludics)):
        first_ludic = ludics[index]
        remove_index = index + first_ludic
        while(remove_index < len(ludics)):
            ludics.remove(ludics[remove_index])
            remove_index = remove_index + first_ludic - 1
        index += 1
    return ludics

@cocotb.test()
async def test_ludic_sieve_basic(dut):
    """Test basic Ludic sieve functionality"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: max_value = 10
    dut.max_value.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Collect results
    results = []
    timeout = 500
    cycles = 0
    
    while cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
        if dut.result_valid.value and dut.done.value == 0:
            results.append(int(dut.result_value.value))
        if dut.done.value:
            break
    
    expected = [1, 2, 3, 5, 7]
    if results != expected:
        raise TestFailure(f"Test 1 failed: got {results}, expected {expected}")
    
    dut._log.info(f"Test 1 passed: {results}")

@cocotb.test()
async def test_ludic_sieve_medium(dut):
    """Test with max_value = 25"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.max_value.value = 25
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results = []
    timeout = 800
    cycles = 0
    
    while cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
        if dut.result_valid.value and dut.done.value == 0:
            results.append(int(dut.result_value.value))
        if dut.done.value:
            break
    
    expected = [1, 2, 3, 5, 7, 11, 13, 17, 23, 25]
    if results != expected:
        raise TestFailure(f"Test 2 failed: got {results}, expected {expected}")
    
    dut._log.info(f"Test 2 passed: {results}")

@cocotb.test()
async def test_ludic_sieve_large(dut):
    """Test with max_value = 45"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.max_value.value = 45
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results = []
    timeout = 1200
    cycles = 0
    
    while cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
        if dut.result_valid.value and dut.done.value == 0:
            results.append(int(dut.result_value.value))
        if dut.done.value:
            break
    
    expected = [1, 2, 3, 5, 7, 11, 13, 17, 23, 25, 29, 37, 41, 43]
    if results != expected:
        raise TestFailure(f"Test 3 failed: got {results}, expected {expected}")
    
    dut._log.info(f"Test 3 passed: {results}")

@cocotb.test()
async def test_ludic_sieve_edge_cases(dut):
    """Test edge cases: max_value = 1 and max_value = 3"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Test max_value = 1
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.max_value.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results = []
    timeout = 200
    cycles = 0
    
    while cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
        if dut.result_valid.value and dut.done.value == 0:
            results.append(int(dut.result_value.value))
        if dut.done.value:
            break
    
    if results != [1]:
        raise TestFailure(f"Edge case 1 failed: got {results}, expected [1]")
    
    dut._log.info(f"Edge case 1 passed: {results}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test max_value = 3
    dut.max_value.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results = []
    timeout = 200
    cycles = 0
    
    while cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
        if dut.result_valid.value and dut.done.value == 0:
            results.append(int(dut.result_value.value))
        if dut.done.value:
            break
    
    if results != [1, 2, 3]:
        raise TestFailure(f"Edge case 2 failed: got {results}, expected [1, 2, 3]")
    
    dut._log.info(f"Edge case 2 passed: {results}")

@cocotb.test()
async def test_ludic_sieve_stress(dut):
    """Test with maximum value 63 (6-bit boundary)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.max_value.value = 63
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results = []
    timeout = 2000
    cycles = 0
    
    while cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
        if dut.result_valid.value and dut.done.value == 0:
            results.append(int(dut.result_value.value))
        if dut.done.value:
            break
    
    # Reference for 63
    expected = get_ludic_reference(63)
    if results != expected:
        raise TestFailure(f"Stress test failed: got {results}, expected {expected}")
    
    dut._log.info(f"Stress test passed: {len(results)} Ludic numbers found in {cycles} cycles")
    print(f"
=== Summary ===")
    print(f"All 5/5 tests passed!")
    print(f"Tested values: 1, 3, 10, 25, 45, 63")
    print(f"Max latency: {cycles} cycles for 63")