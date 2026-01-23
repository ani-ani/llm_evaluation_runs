import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_buffet_optimizer_basic(dut):
    """Test basic discrete dish"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load test case: 2 dishes, weight 15
    # Dish 1: D 4 10 1 (discrete, weight=4, t=10, dt=1)
    # Dish 2: C 6 1 (continuous, t=6, dt=1)
    
    dut.dish_count.value = 2
    dut.total_weight.value = 15
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load discrete dish
    # type=0, weight=4, t=10, dt=1
    # Packed format: {type[0], weight[15:0], t[15:0], dt[15:0]}
    dut.dish_data_valid.value = 1
    dut.dish_data.value = (0 << 47) | (4 << 32) | (10 << 16) | 1
    dut.dish_info_index.value = 0
    await RisingEdge(dut.clk)
    
    # Load continuous dish  
    # type=1, weight=0, t=6, dt=1
    dut.dish_data.value = (1 << 47) | (0 << 32) | (6 << 16) | 1
    dut.dish_info_index.value = 1
    await RisingEdge(dut.clk)
    dut.dish_data_valid.value = 0
    
    # Wait for computation
    for _ in range(200):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    # Check result (40.5 in Q16.16 = 40.5 * 65536 = 2654208)
    result = int(dut.result.value)
    expected = int(40.5 * 65536)
    
    if result != expected:
        raise TestFailure(f"Expected {expected} ({40.5}), got {result} ({result/65536.0})")
    
    print("Test 1 passed: Basic discrete+continuous")

@cocotb.test()
async def test_buffet_optimizer_impossible(dut):
    """Test impossible case"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Case: 2 dishes, weight 19
    # Dish 1: D 4 5 1
    # Dish 2: D 6 3 2
    # 4x4 = 16, 6x3 = 18, no combination gives exactly 19
    
    dut.dish_count.value = 2
    dut.total_weight.value = 19
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load two discrete dishes
    dut.dish_data_valid.value = 1
    dut.dish_data.value = (0 << 47) | (4 << 32) | (5 << 16) | 1
    dut.dish_info_index.value = 0
    await RisingEdge(dut.clk)
    
    dut.dish_data.value = (0 << 47) | (6 << 32) | (3 << 16) | 2
    dut.dish_info_index.value = 1
    await RisingEdge(dut.clk)
    dut.dish_data_valid.value = 0
    
    # Wait for completion
    for _ in range(200):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    # Check for impossible indicator (0xFFFFFFFF)
    result = int(dut.result.value)
    
    if result != 0xFFFFFFFF:
        raise TestFailure(f"Expected impossible (0xFFFFFFFF), got {result}")
    
    print("Test 2 passed: Impossible case")

@cocotb.test()
async def test_buffet_optimizer_continuous_only(dut):
    """Test continuous dishes only"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Single continuous dish: C 6 1, weight 5
    # Optimal: x=6, but limited to 5
    # Tastiness = 6*5 - 1*25/2 = 30 - 12.5 = 17.5
    
    dut.dish_count.value = 1
    dut.total_weight.value = 5
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.dish_data_valid.value = 1
    dut.dish_data.value = (1 << 47) | (0 << 32) | (6 << 16) | 1
    dut.dish_info_index.value = 0
    await RisingEdge(dut.clk)
    dut.dish_data_valid.value = 0
    
    for _ in range(200):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    result = int(dut.result.value)
    expected = int(17.5 * 65536)
    
    if abs(result - expected) > 100:
        raise TestFailure(f"Expected {expected} ({17.5}), got {result}")
    
    print("Test 3 passed: Continuous only")

@cocotb.test()
async def test_buffet_optimizer_discrete_only(dut):
    """Test discrete dishes only"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 3 discrete dishes, weight 10
    # D 3 5 1, D 4 8 2, D 5 10 3
    # Best: 2x3 + 1x4 = 10, tastiness = 5 + (5-1) + 8 = 17
    
    dut.dish_count.value = 3
    dut.total_weight.value = 10
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.dish_data_valid.value = 1
    dut.dish_data.value = (0 << 47) | (3 << 32) | (5 << 16) | 1
    dut.dish_info_index.value = 0
    await RisingEdge(dut.clk)
    
    dut.dish_data.value = (0 << 47) | (4 << 32) | (8 << 16) | 2
    dut.dish_info_index.value = 1
    await RisingEdge(dut.clk)
    
    dut.dish_data.value = (0 << 47) | (5 << 32) | (10 << 16) | 3
    dut.dish_info_index.value = 2
    await RisingEdge(dut.clk)
    dut.dish_data_valid.value = 0
    
    for _ in range(200):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    result = int(dut.result.value)
    expected = int(17.0 * 65536)
    
    if result != expected:
        raise TestFailure(f"Expected {expected} ({17.0}), got {result}")
    
    print("Test 4 passed: Discrete only")

@cocotb.test()
async def test_buffet_optimizer_zero_decay(dut):
    """Test dishes with zero decay"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Continuous dish: C 10 0, weight 3
    # Should give 30 tastiness (constant)
    
    dut.dish_count.value = 1
    dut.total_weight.value = 3
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.dish_data_valid.value = 1
    dut.dish_data.value = (1 << 47) | (0 << 32) | (10 << 16) | 0
    dut.dish_info_index.value = 0
    await RisingEdge(dut.clk)
    dut.dish_data_valid.value = 0
    
    for _ in range(200):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    result = int(dut.result.value)
    expected = int(30.0 * 65536)
    
    if result != expected:
        raise TestFailure(f"Expected {expected} ({30.0}), got {result}")
    
    print("Test 5 passed: Zero decay")

print("All buffet optimizer tests completed")
