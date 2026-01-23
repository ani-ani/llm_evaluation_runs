import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_ks_smooth_basic(dut):
    """Test basic K_S-smooth minimum changes calculation"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: N=3, K=3, S=5, array=[1,2,3] -> 1 change
    dut.N.value = 3
    dut.K.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for ready
    while not dut.ready.value:
        await RisingEdge(dut.clk)
    
    # Send elements
    for val in [1, 2, 3]:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.min_changes.value)
    if result != 1:
        raise TestFailure(f"Expected 1, got {result}")
    print(f"Test 1 passed: min_changes = {result}")

@cocotb.test()
async def test_ks_smooth_case2(dut):
    """Test case 2: N=6, K=3, array=[1,2,3,3,2,1] -> 3 changes"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.N.value = 6
    dut.K.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.ready.value:
        await RisingEdge(dut.clk)
    
    for val in [1, 2, 3, 3, 2, 1]:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.min_changes.value)
    if result != 3:
        raise TestFailure(f"Expected 3, got {result}")
    print(f"Test 2 passed: min_changes = {result}")

@cocotb.test()
async def test_ks_smooth_case3(dut):
    """Test case 3: N=5, K=1, array=[1,2,3,4,5] -> 4 changes"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.N.value = 5
    dut.K.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.ready.value:
        await RisingEdge(dut.clk)
    
    for val in [1, 2, 3, 4, 5]:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.min_changes.value)
    if result != 4:
        raise TestFailure(f"Expected 4, got {result}")
    print(f"Test 3 passed: min_changes = {result}")

@cocotb.test()
async def test_ks_smooth_all_same(dut):
    """Test case with all elements same (already smooth)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.N.value = 4
    dut.K.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.ready.value:
        await RisingEdge(dut.clk)
    
    for val in [5, 5, 5, 5]:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.min_changes.value)
    if result != 0:
        raise TestFailure(f"Expected 0, got {result}")
    print(f"Test 4 passed: min_changes = {result}")

@cocotb.test()
async def test_ks_smooth_max_constraints(dut):
    """Test edge case with maximum constraints"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 64 elements, K=8
    dut.N.value = 64
    dut.K.value = 8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.ready.value:
        await RisingEdge(dut.clk)
    
    # Send pattern where each group has 8 elements
    # Group 0: all 0s, Group 1: all 1s, etc.
    for i in range(64):
        dut.data_in.value = i % 8
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.min_changes.value)
    # Already smooth, should be 0
    if result != 0:
        raise TestFailure(f"Expected 0, got {result}")
    print(f"Test 5 passed: min_changes = {result}")
    
    total = 5
    print(f"
=== SUMMARY: {total}/{total} tests passed ===")
