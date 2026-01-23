import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_lounge_planner_basic(dut):
    """Test basic functionality with sample input 1"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.edge_load.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Sample Input 1:
    # 4 4
    # 1 2 2
    # 2 3 1
    # 3 4 1
    # 4 1 2
    # Expected: 3 lounges
    
    dut.node_count.value = 4
    dut.edge_count.value = 4
    await RisingEdge(dut.clk)
    
    # Load edges
    edges = [(1,2,2), (2,3,1), (3,4,1), (4,1,2)]
    for i, (a, b, c) in enumerate(edges):
        dut.edge_index.value = i
        dut.edge_a.value = a
        dut.edge_b.value = b
        dut.edge_c.value = c
        dut.edge_load.value = 1
        await RisingEdge(dut.clk)
        dut.edge_load.value = 0
        await RisingEdge(dut.clk)
    
    # Start solving
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max ~2000 cycles, but will finish earlier)
    for _ in range(3000):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            break
    
    if dut.valid.value != 1:
        raise TestFailure("Valid signal not set after computation")
    
    if dut.impossible.value == 1:
        raise TestFailure("Result is impossible, but expected 3")
    
    if int(dut.min_lounges.value) != 3:
        raise TestFailure(f"Expected min_lounges=3, got {int(dut.min_lounges.value)}")
    
    dut._log.info("Test 1 passed: 3 lounges")

@cocotb.test()
async def test_lounge_planner_impossible(dut):
    """Test impossible case with sample input 2"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.edge_load.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Sample Input 2: 5 5, all c=1, leads to odd cycle
    dut.node_count.value = 5
    dut.edge_count.value = 5
    await RisingEdge(dut.clk)
    
    edges = [(1,2,1), (2,3,1), (2,4,1), (2,5,1), (4,5,1)]
    for i, (a, b, c) in enumerate(edges):
        dut.edge_index.value = i
        dut.edge_a.value = a
        dut.edge_b.value = b
        dut.edge_c.value = c
        dut.edge_load.value = 1
        await RisingEdge(dut.clk)
        dut.edge_load.value = 0
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(3000):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            break
    
    if dut.valid.value != 1:
        raise TestFailure("Valid signal not set")
    
    if dut.impossible.value != 1:
        raise TestFailure(f"Expected impossible, got min_lounges={int(dut.min_lounges.value)}")
    
    dut._log.info("Test 2 passed: correctly identified impossible")

@cocotb.test()
async def test_lounge_planner_test3(dut):
    """Test with sample input 3: 4 5, result=2"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.edge_load.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Sample Input 3: 4 5, result=2
    dut.node_count.value = 4
    dut.edge_count.value = 5
    await RisingEdge(dut.clk)
    
    edges = [(1,2,1), (2,3,0), (2,4,1), (3,1,1), (3,4,1)]
    for i, (a, b, c) in enumerate(edges):
        dut.edge_index.value = i
        dut.edge_a.value = a
        dut.edge_b.value = b
        dut.edge_c.value = c
        dut.edge_load.value = 1
        await RisingEdge(dut.clk)
        dut.edge_load.value = 0
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(3000):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            break
    
    if dut.valid.value != 1:
        raise TestFailure("Valid signal not set")
    
    if dut.impossible.value == 1:
        raise TestFailure("Result is impossible, but expected 2")
    
    if int(dut.min_lounges.value) != 2:
        raise TestFailure(f"Expected min_lounges=2, got {int(dut.min_lounges.value)}")
    
    dut._log.info("Test 3 passed: 2 lounges")

@cocotb.test()
async def test_lounge_planner_edge_case_zero(dut):
    """Test edge case: all constraints are c=0 (no lounges needed)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.edge_load.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.node_count.value = 3
    dut.edge_count.value = 2
    await RisingEdge(dut.clk)
    
    edges = [(1,2,0), (2,3,0)]
    for i, (a, b, c) in enumerate(edges):
        dut.edge_index.value = i
        dut.edge_a.value = a
        dut.edge_b.value = b
        dut.edge_c.value = c
        dut.edge_load.value = 1
        await RisingEdge(dut.clk)
        dut.edge_load.value = 0
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(3000):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            break
    
    if dut.valid.value != 1:
        raise TestFailure("Valid signal not set")
    
    if dut.impossible.value == 1:
        raise TestFailure("Result should not be impossible")
    
    if int(dut.min_lounges.value) != 0:
        raise TestFailure(f"Expected min_lounges=0, got {int(dut.min_lounges.value)}")
    
    dut._log.info("Test 4 passed: 0 lounges")

@cocotb.test()
async def test_lounge_planner_all_ones(dut):
    """Test edge case: all c=2 (all airports need lounges)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.edge_load.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.node_count.value = 4
    dut.edge_count.value = 3
    await RisingEdge(dut.clk)
    
    edges = [(1,2,2), (2,3,2), (3,4,2)]
    for i, (a, b, c) in enumerate(edges):
        dut.edge_index.value = i
        dut.edge_a.value = a
        dut.edge_b.value = b
        dut.edge_c.value = c
        dut.edge_load.value = 1
        await RisingEdge(dut.clk)
        dut.edge_load.value = 0
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(3000):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            break
    
    if dut.valid.value != 1:
        raise TestFailure("Valid signal not set")
    
    if dut.impossible.value == 1:
        raise TestFailure("Result should not be impossible")
    
    if int(dut.min_lounges.value) != 4:
        raise TestFailure(f"Expected min_lounges=4, got {int(dut.min_lounges.value)}")
    
    dut._log.info("Test 5 passed: 4 lounges")