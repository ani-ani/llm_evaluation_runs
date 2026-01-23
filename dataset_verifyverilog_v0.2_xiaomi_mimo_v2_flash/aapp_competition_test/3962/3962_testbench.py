import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_chair_arrangement(dut):
    """Test the chair arrangement module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.l_i.value = 0
    dut.r_i.value = 0
    dut.guest_index.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=3, l=[1,1,1], r=[1,1,1]
    # Expected: max(1,1)*3 + 3 = 3 + 3 = 6
    dut.n.value = 3
    for i in range(3):
        dut.l_i.value = 1
        dut.r_i.value = 1
        dut.guest_index.value = i
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 6, f"Test 1 failed: expected 6, got {dut.result.value}"
    print(f"Test 1 Passed: n=3, all [1,1] -> Result: {dut.result.value}")
    await RisingEdge(dut.clk)
    
    # Test case 2: n=4, pairs [1,2], [2,1], [3,5], [5,3]
    # Sorted l: [1,2,3,5], Sorted r: [1,2,3,5]
    # Sum max: 1+2+3+5 = 11, +4 = 15
    dut.n.value = 4
    pairs = [(1,2), (2,1), (3,5), (5,3)]
    for i, (l, r) in enumerate(pairs):
        dut.l_i.value = l
        dut.r_i.value = r
        dut.guest_index.value = i
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 15, f"Test 2 failed: expected 15, got {dut.result.value}"
    print(f"Test 2 Passed: n=4, result: {dut.result.value}")
    await RisingEdge(dut.clk)
    
    # Test case 3: n=1, l=[5], r=[6]
    # Expected: max(5,6) + 1 = 6 + 1 = 7
    dut.n.value = 1
    dut.l_i.value = 5
    dut.r_i.value = 6
    dut.guest_index.value = 0
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 7, f"Test 3 failed: expected 7, got {dut.result.value}"
    print(f"Test 3 Passed: n=1, [5,6] -> Result: {dut.result.value}")
    await RisingEdge(dut.clk)
    
    # Test case 4: n=2, pairs [1000, 0], [0, 1000]
    # Sorted l: [0, 1000], Sorted r: [0, 1000]
    # Sum max: 0 + 1000 = 1000, +2 = 1002
    dut.n.value = 2
    pairs = [(1000, 0), (0, 1000)]
    for i, (l, r) in enumerate(pairs):
        dut.l_i.value = l
        dut.r_i.value = r
        dut.guest_index.value = i
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 1002, f"Test 4 failed: expected 1002, got {dut.result.value}"
    print(f"Test 4 Passed: n=2, result: {dut.result.value}")
    await RisingEdge(dut.clk)
    
    # Test case 5: n=3, pairs [1,1], [2,2], [3,3]
    # Sorted l: [1,2,3], Sorted r: [1,2,3]
    # Sum max: 1+2+3=6, +3 = 9
    dut.n.value = 3
    pairs = [(1,1), (2,2), (3,3)]
    for i, (l, r) in enumerate(pairs):
        dut.l_i.value = l
        dut.r_i.value = r
        dut.guest_index.value = i
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 9, f"Test 5 failed: expected 9, got {dut.result.value}"
    print(f"Test 5 Passed: n=3, result: {dut.result.value}")
    
    print("All 5 tests passed!")