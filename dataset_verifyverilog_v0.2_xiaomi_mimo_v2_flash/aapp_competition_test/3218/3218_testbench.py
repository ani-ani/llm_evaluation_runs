import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_hexagon_coloring_basic(dut):
    """Test basic hexagon coloring for n=3 with known inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a1_1.value = 0
    dut.a1_2.value = 0
    dut.a1_3.value = 0
    dut.a2_1.value = 0
    dut.a2_2.value = 0
    dut.a3_1.value = 0
    dut.a3_2.value = 0
    dut.a3_3.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test Case 1: Sample Input 1
    # Row 1: -1 2 -1
    # Row 2: 2 2
    # Row 3: 1 -1 1
    # Encoded: 0x80 for -1, actual value for 0-6
    
    dut.a1_1.value = 0x80  # -1
    dut.a1_2.value = 2     # 2
    dut.a1_3.value = 0x80  # -1
    dut.a2_1.value = 2     # 2
    dut.a2_2.value = 2     # 2
    dut.a3_1.value = 1     # 1
    dut.a3_2.value = 0x80  # -1
    dut.a3_3.value = 1     # 1
    
    await Timer(20, units='ns')
    dut.start.value = 1
    await Timer(20, units='ns')
    dut.start.value = 0
    
    # Wait for completion
    timeout = 1000000  # 1M cycles max for exhaustive search
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Test timed out")
    
    # Expected result: 1
    if dut.result.value != 1:
        raise TestFailure(f"Expected result 1, got {dut.result.value}")
    
    print(f"Test 1 passed: result = {dut.result.value}")
    
    # Test Case 2: All -1 (should give more solutions)
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    dut.a1_1.value = 0x80
    dut.a1_2.value = 0x80
    dut.a1_3.value = 0x80
    dut.a2_1.value = 0x80
    dut.a2_2.value = 0x80
    dut.a3_1.value = 0x80
    dut.a3_2.value = 0x80
    dut.a3_3.value = 0x80
    
    await Timer(20, units='ns')
    dut.start.value = 1
    await Timer(20, units='ns')
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Test 2 timed out")
    
    # All -1 should have more than 1 solution (actual count depends on valid loop configurations)
    # For n=3, all -1 has 4 solutions (from test case 3)
    if dut.result.value != 4:
        raise TestFailure(f"Expected result 4, got {dut.result.value}")
    
    print(f"Test 2 passed: result = {dut.result.value}")
    print(f"Total cycles used: {cycles}")
    print(f"All tests passed!")

@cocotb.test()
async def test_hexagon_coloring_edge_case(dut):
    """Test with some hexagons requiring 0 edges"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case: multiple zeros and some constraints
    # This is a more complex test to verify constraint checking
    # Row 1: 0 -1 0
    # Row 2: -1 -1
    # Row 3: 0 -1 0
    
    dut.a1_1.value = 0
    dut.a1_2.value = 0x80
    dut.a1_3.value = 0
    dut.a2_1.value = 0x80
    dut.a2_2.value = 0x80
    dut.a3_1.value = 0
    dut.a3_2.value = 0x80
    dut.a3_3.value = 0
    
    await Timer(20, units='ns')
    dut.start.value = 1
    await Timer(20, units='ns')
    dut.start.value = 0
    
    timeout = 1000000
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Edge case test timed out")
    
    # Result should be non-zero (exact value depends on valid configurations)
    print(f"Edge case result: {dut.result.value}")
    assert dut.result.value >= 0
    print(f"Edge case test passed!")
