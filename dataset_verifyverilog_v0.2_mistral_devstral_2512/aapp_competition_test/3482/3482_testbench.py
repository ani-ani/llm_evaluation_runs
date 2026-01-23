import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_transit_card_optimizer(dut):
    """Test the transit card optimizer with scaled-down examples"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.l.value = 0
    for i in range(4):
        dut.price[i].value = 0
        dut.trip_start[i].value = 0
        dut.trip_end[i].value = 0
    for i in range(3):
        dut.duration[i].value = 0
    dut.t.value = 0
    dut.n.value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 3 price levels, 7 days each, 30 days total, 0 trips
    # Expected: 405
    # Breakdown: Days 1-7: 7*20=140, Days 8-14: 7*15=105, Days 15-30: 16*10=160, Total=405
    dut.l.value = 3
    dut.price[0].value = 20
    dut.price[1].value = 15
    dut.price[2].value = 10
    dut.duration[0].value = 7
    dut.duration[1].value = 7
    dut.t.value = 16  # Scaled down from 30 to fit 16 days
    dut.n.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 64 cycles)
    for _ in range(70):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 1: Done signal not asserted within 70 cycles")
    
    # For 16 days: Days 1-7: 7*20=140, Days 8-14: 7*15=105, Days 15-16: 2*10=20, Total=265
    expected1 = 265
    actual1 = int(dut.min_cost.value)
    print(f"Test 1 - Expected: {expected1}, Got: {actual1}")
    if abs(actual1 - expected1) > 1:
        raise TestFailure(f"Test 1 failed: expected {expected1}, got {actual1}")
    
    # Test Case 2: Same pricing, 16 days, 2 trips: [5,5] and [15,16]
    # Trip 1: day 5, Trip 2: days 15-16
    # Need coverage for 14 days
    # Days 1-4: 4*20=80, Days 6-14: 9*15=135, Total=215
    await RisingEdge(dut.clk)
    dut.l.value = 3
    dut.price[0].value = 20
    dut.price[1].value = 15
    dut.price[2].value = 10
    dut.duration[0].value = 7
    dut.duration[1].value = 7
    dut.t.value = 16
    dut.n.value = 2
    dut.trip_start[0].value = 5
    dut.trip_end[0].value = 5
    dut.trip_start[1].value = 15
    dut.trip_end[1].value = 16
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(70):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 2: Done signal not asserted within 70 cycles")
    
    # Two options: (1) Keep card: Days 1-4 (4*20=80) + 6-14 (9*15=135) = 215
    # (2) Two intervals: 1-4 (80) + 6-14 (135) = 215 (same due to gap)
    expected2 = 215
    actual2 = int(dut.min_cost.value)
    print(f"Test 2 - Expected: {expected2}, Got: {actual2}")
    if abs(actual2 - expected2) > 1:
        raise TestFailure(f"Test 2 failed: expected {expected2}, got {actual2}")
    
    # Test Case 3: Simple case - 1 price level, 5 days, no trips
    # Expected: 5*20 = 100
    await RisingEdge(dut.clk)
    dut.l.value = 1
    dut.price[0].value = 20
    dut.t.value = 5
    dut.n.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(70):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 3: Done signal not asserted within 70 cycles")
    
    expected3 = 100
    actual3 = int(dut.min_cost.value)
    print(f"Test 3 - Expected: {expected3}, Got: {actual3}")
    if abs(actual3 - expected3) > 1:
        raise TestFailure(f"Test 3 failed: expected {expected3}, got {actual3}")
    
    # Test Case 4: Two price levels, 3 days each, 6 days total, gap in middle
    # p1=30, p2=10, d1=3, days 1-3 use p1, days 4-6 use p2
    # Trips: days 2-3 (gap), so need days 1, 4, 5, 6
    # Option 1: two intervals: day1 (30) + days4-6 (3*10=30) = 60
    # Option 2: one interval covering all: 6 days, but with pricing reset at day4
    # Actually if continuous: days 1,2,3,4,5,6 where 2-3 are trip
    # If one interval from 1-6: cost = days1-3 (3*30=90) + days4-6 (3*10=30) = 120
    # But trip days 2-3 don't need coverage, so we pay for day1 only in first 3 days
    # Then interval continues, days4-6 use p2: 3*10=30, total=60
    # Wait, pricing is based on consecutive days since interval start, not calendar days
    # So if interval starts day1: day1=30, day2=30, day3=30, day4=10, day5=10, day6=10
    # But we don't need day2,3, so we pay 30+10+10+10=60
    # If we start new interval at day4: day4=30, day5=30, day6=30 = 90
    # So minimum is 60
    await RisingEdge(dut.clk)
    dut.l.value = 2
    dut.price[0].value = 30
    dut.price[1].value = 10
    dut.duration[0].value = 3
    dut.t.value = 6
    dut.n.value = 1
    dut.trip_start[0].value = 2
    dut.trip_end[0].value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(70):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 4: Done signal not asserted within 70 cycles")
    
    expected4 = 60
    actual4 = int(dut.min_cost.value)
    print(f"Test 4 - Expected: {expected4}, Got: {actual4}")
    if abs(actual4 - expected4) > 1:
        raise TestFailure(f"Test 4 failed: expected {expected4}, got {actual4}")
    
    print(f"
All tests completed. Results: {actual1}/{expected1}, {actual2}/{expected2}, {actual3}/{expected3}, {actual4}/{expected4}")
    print("All tests passed!")