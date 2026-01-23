import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

# Helper to pack car data into the module
async def load_car(dut, idx, direction, arrival, irritation):
    dut.car_idx.value = idx
    dut.car_dir.value = direction
    dut.car_arrival.value = arrival
    dut.car_irritation.value = irritation
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_traffic_scheduler_basic(dut):
    """Test the traffic scheduler with sample inputs"""
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Original sample input
    # 8 3
    # W 10 0
    # W 10 3
    # E 17 4
    # Expected: 0 irritated
    
    # Load cars (we pad to 8 cars since module expects fixed 8)
    # Car 0: W 10 0
    await load_car(dut, 0, 0, 10, 0)
    # Car 1: W 10 3
    await load_car(dut, 1, 0, 10, 3)
    # Car 2: E 17 4
    await load_car(dut, 2, 1, 17, 4)
    # Pad with dummy cars (arrival 65535, irritation 0 so they don't affect result)
    for i in range(3, 8):
        await load_car(dut, i, 0, 65535, 0)
    
    # Start processing
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Module did not finish in time")
    
    # Check result
    result = int(dut.result_min_irritated.value)
    print(f"Test 1 - Result: {result} (Expected: 0)")
    assert result == 0, f"Expected 0 irritated, got {result}"
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: Second sample input
    # 100 5
    # W 0 200
    # W 5 201
    # E 95 1111
    # E 95 1
    # E 95 11
    # Expected: 1 irritated
    
    # Car 0: W 0 200
    await load_car(dut, 0, 0, 0, 200)
    # Car 1: W 5 201
    await load_car(dut, 1, 0, 5, 201)
    # Car 2: E 95 1111
    await load_car(dut, 2, 1, 95, 1111)
    # Car 3: E 95 1
    await load_car(dut, 3, 1, 95, 1)
    # Car 4: E 95 11
    await load_car(dut, 4, 1, 95, 11)
    # Pad rest
    for i in range(5, 8):
        await load_car(dut, i, 0, 65535, 0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Module did not finish in time")
    
    result = int(dut.result_min_irritated.value)
    print(f"Test 2 - Result: {result} (Expected: 1)")
    assert result == 1, f"Expected 1 irritated, got {result}"
    
    print("All tests passed!")

@cocotb.test()
async def test_traffic_scheduler_edge_cases(dut):
    """Test edge cases for the scheduler"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge Case: All cars same direction, no irritation possible
    # Car 0: W 0 5
    # Car 1: W 10 5 (3s gap + 8s pass = 11s, so 10+5=15, 11 < 15, OK)
    # Car 2: W 20 5 (previous finish at 11+8=19, 19+3=22, 20+5=25, 22 < 25, OK)
    await load_car(dut, 0, 0, 0, 5)
    await load_car(dut, 1, 0, 10, 5)
    await load_car(dut, 2, 0, 20, 5)
    for i in range(3, 8):
        await load_car(dut, i, 0, 65535, 0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test 3 timeout")
    
    result = int(dut.result_min_irritated.value)
    print(f"Edge Test 1 - Result: {result} (Expected: 0)")
    assert result == 0
    
    # Edge Case: Direction switch forces irritation
    # Car 0: W 0 0 (go at 0)
    # Car 1: E 5 2 (need switch: finish W at 0+8=8, so E can go at 8, wait=3, irritation=2 -> IRRITATED)
    await load_car(dut, 0, 0, 0, 0)
    await load_car(dut, 1, 1, 5, 2)
    for i in range(2, 8):
        await load_car(dut, i, 0, 65535, 0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test 4 timeout")
    
    result = int(dut.result_min_irritated.value)
    print(f"Edge Test 2 - Result: {result} (Expected: 1)")
    assert result == 1
    
    print("Edge case tests passed!")