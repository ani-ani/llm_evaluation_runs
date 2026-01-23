import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_subarray_repeated(dut):
    """Test maximum subarray sum with repeated array"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.k.value = 0
    for i in range(4):
        dut.a[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case 1: [10, 20, -30, -1], n=4, k=3, expected=30
    print("Test 1: [10, 20, -30, -1], n=4, k=3")
    dut.n.value = 4
    dut.k.value = 3
    dut.a[0].value = 10
    dut.a[1].value = 20
    dut.a[2].value = -30
    dut.a[3].value = -1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    print(f"Result: {result}, Expected: 30")
    assert result == 30, f"Test 1 failed: got {result}, expected 30"
    
    # Test case 2: [-1, 10, 20], n=3, k=2, expected=59
    print("
Test 2: [-1, 10, 20], n=3, k=2")
    await Timer(20, units='ns')
    dut.n.value = 3
    dut.k.value = 2
    dut.a[0].value = -1 & 0xFFFFFFFF
    dut.a[1].value = 10
    dut.a[2].value = 20
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    # Convert from signed if needed
    if result >= 0x80000000:
        result = result - 0x100000000
    print(f"Result: {result}, Expected: 59")
    assert result == 59, f"Test 2 failed: got {result}, expected 59"
    
    # Test case 3: [-1, -2, -3], n=3, k=3, expected=-1
    print("
Test 3: [-1, -2, -3], n=3, k=3")
    await Timer(20, units='ns')
    dut.n.value = 3
    dut.k.value = 3
    dut.a[0].value = -1 & 0xFFFFFFFF
    dut.a[1].value = -2 & 0xFFFFFFFF
    dut.a[2].value = -3 & 0xFFFFFFFF
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    if result >= 0x80000000:
        result = result - 0x100000000
    print(f"Result: {result}, Expected: -1")
    assert result == -1, f"Test 3 failed: got {result}, expected -1"
    
    # Edge case: Single element, k=1
    print("
Test 4: [15], n=1, k=1, expected=15")
    await Timer(20, units='ns')
    dut.n.value = 1
    dut.k.value = 1
    dut.a[0].value = 15
    for i in range(1, 4):
        dut.a[i].value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    print(f"Result: {result}, Expected: 15")
    assert result == 15, f"Test 4 failed: got {result}, expected 15"
    
    # Edge case: Two elements, k=3
    print("
Test 5: [5, -2], n=2, k=3, expected=5")
    await Timer(20, units='ns')
    dut.n.value = 2
    dut.k.value = 3
    dut.a[0].value = 5
    dut.a[1].value = -2 & 0xFFFFFFFF
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    if result >= 0x80000000:
        result = result - 0x100000000
    print(f"Result: {result}, Expected: 5")
    assert result == 5, f"Test 5 failed: got {result}, expected 5"
    
    print("
=== All 5 tests passed ===")