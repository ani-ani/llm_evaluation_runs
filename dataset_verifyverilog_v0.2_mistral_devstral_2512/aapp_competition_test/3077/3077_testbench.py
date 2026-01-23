import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_tower_defense_basic(dut):
    """Test basic case with 1 village, 3 minions, r=3"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load test case 1: 1 village, 3 minions, r=3
    dut.n_used.value = 1
    dut.m_used.value = 3
    dut.max_r.value = 3
    
    # Village at (0,0) with r=1
    dut.village_x[0].value = 0
    dut.village_y[0].value = 0
    dut.village_r[0].value = 1
    
    # Minions at (3,3), (-3,3), (3,-3)
    dut.minion_x[0].value = 3
    dut.minion_y[0].value = 3
    dut.minion_x[1].value = -3
    dut.minion_y[1].value = 3
    dut.minion_x[2].value = 3
    dut.minion_y[2].value = -3
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Done signal not asserted within timeout"
    assert dut.max_killed.value == 1, f"Expected 1, got {dut.max_killed.value}"
    print("Test 1 passed: 1 village, 3 minions, r=3 -> 1 killed")

@cocotb.test()
async def test_tower_defense_case2(dut):
    """Test case 2 with 1 village, 5 minions, r=3"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_used.value = 1
    dut.m_used.value = 5
    dut.max_r.value = 3
    
    # Village at (0,0) r=1
    dut.village_x[0].value = 0
    dut.village_y[0].value = 0
    dut.village_r[0].value = 1
    
    # Minions: (3,3), (-3,3), (3,-3), (3,0), (0,3)
    dut.minion_x[0].value = 3
    dut.minion_y[0].value = 3
    dut.minion_x[1].value = -3
    dut.minion_y[1].value = 3
    dut.minion_x[2].value = 3
    dut.minion_y[2].value = -3
    dut.minion_x[3].value = 3
    dut.minion_y[3].value = 0
    dut.minion_x[4].value = 0
    dut.minion_y[4].value = 3
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1
    assert dut.max_killed.value == 3, f"Expected 3, got {dut.max_killed.value}"
    print("Test 2 passed: 1 village, 5 minions, r=3 -> 3 killed")

@cocotb.test()
async def test_tower_defense_case3(dut):
    """Test case 3 with 4 villages, 10 minions, r=100"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_used.value = 4
    dut.m_used.value = 10
    dut.max_r.value = 100
    
    # 4 villages at corners of 10x10 square, r=3
    dut.village_x[0].value = 0
    dut.village_y[0].value = 0
    dut.village_r[0].value = 3
    dut.village_x[1].value = 10
    dut.village_y[1].value = 0
    dut.village_r[1].value = 3
    dut.village_x[2].value = 10
    dut.village_y[2].value = 10
    dut.village_r[2].value = 3
    dut.village_x[3].value = 0
    dut.village_y[3].value = 10
    dut.village_r[3].value = 3
    
    # 10 minions (scaled from example)
    minions = [
        (0,4), (0,5), (0,6), (5,3), (5,-3),
        (5,5), (6,7), (3,6), (10,4), (8,4)
    ]
    for i, (mx, my) in enumerate(minions):
        dut.minion_x[i].value = mx
        dut.minion_y[i].value = my
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1
    assert dut.max_killed.value == 5, f"Expected 5, got {dut.max_killed.value}"
    print("Test 3 passed: 4 villages, 10 minions, r=100 -> 5 killed")

@cocotb.test()
async def test_tower_defense_no_villages(dut):
    """Test with no villages - should kill all minions"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_used.value = 0
    dut.m_used.value = 3
    dut.max_r.value = 5
    
    dut.minion_x[0].value = 0
    dut.minion_y[0].value = 0
    dut.minion_x[1].value = 2
    dut.minion_y[1].value = 0
    dut.minion_x[2].value = 4
    dut.minion_y[2].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1
    assert dut.max_killed.value == 3, f"Expected 3, got {dut.max_killed.value}"
    print("Test 4 passed: No villages, 3 minions, r=5 -> 3 killed")

@cocotb.test()
async def test_tower_defense_edge_case(dut):
    """Test edge case: minions too far, result 0"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_used.value = 1
    dut.m_used.value = 1
    dut.max_r.value = 1
    
    # Village at (0,0) r=1
    dut.village_x[0].value = 0
    dut.village_y[0].value = 0
    dut.village_r[0].value = 1
    
    # Minion at (10,10) - too far
    dut.minion_x[0].value = 10
    dut.minion_y[0].value = 10
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1
    assert dut.max_killed.value == 0, f"Expected 0, got {dut.max_killed.value}"
    print("Test 5 passed: Minion too far -> 0 killed")