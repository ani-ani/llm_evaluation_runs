import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_widget_profit_maximizer(dut):
    """Test the widget profit maximizer module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_producers.value = 0
    dut.num_consumers.value = 0
    for i in range(8):
        dut.producer_prices[i].value = 0
        dut.producer_dates[i].value = 0
        dut.consumer_prices[i].value = 0
        dut.consumer_dates[i].value = 0
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Sample Input (adapted to 8-bit)
    # Original: producers [(1,3), (2,1)], consumers [(3,5), (7,2)]
    # Expected: max profit = 5 (producer 2, consumer 7, 1 day)
    
    dut.num_producers.value = 2
    dut.num_consumers.value = 2
    
    # Producer 0: price=1, date=3
    dut.producer_prices[0].value = 1
    dut.producer_dates[0].value = 3
    # Producer 1: price=2, date=1
    dut.producer_prices[1].value = 2
    dut.producer_dates[1].value = 1
    
    # Consumer 0: price=3, date=5
    dut.consumer_prices[0].value = 3
    dut.consumer_dates[0].value = 5
    # Consumer 1: price=7, date=2
    dut.consumer_prices[1].value = 7
    dut.consumer_dates[1].value = 2
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 100
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Timeout waiting for done signal")
    
    result = dut.max_profit.value
    print(f"Test 1 - Expected: 5, Got: {result}")
    if result != 5:
        raise TestFailure(f"Test 1 failed: expected 5, got {result}")
    
    await RisingEdge(dut.clk)
    
    # Test Case 2: Second Sample Input (adapted)
    # Original: producer (10,10), consumer (9,11)
    # Profit = -1, so result should be 0
    
    dut.num_producers.value = 1
    dut.num_consumers.value = 1
    dut.producer_prices[0].value = 10
    dut.producer_dates[0].value = 10
    dut.consumer_prices[0].value = 9
    dut.consumer_dates[0].value = 11
    
    # Clear unused entries
    for i in range(1, 8):
        dut.producer_prices[i].value = 0
        dut.producer_dates[i].value = 0
        dut.consumer_prices[i].value = 0
        dut.consumer_dates[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Timeout waiting for done signal")
    
    result = dut.max_profit.value
    print(f"Test 2 - Expected: 0, Got: {result}")
    if result != 0:
        raise TestFailure(f"Test 2 failed: expected 0, got {result}")
    
    await RisingEdge(dut.clk)
    
    # Test Case 3: Edge case - exact date match (1 day profit)
    # Producer: price=5, date=10
    # Consumer: price=15, date=11
    # Profit/day=10, days=1, total=10
    
    dut.num_producers.value = 1
    dut.num_consumers.value = 1
    dut.producer_prices[0].value = 5
    dut.producer_dates[0].value = 10
    dut.consumer_prices[0].value = 15
    dut.consumer_dates[0].value = 11
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Timeout waiting for done signal")
    
    result = dut.max_profit.value
    print(f"Test 3 - Expected: 10, Got: {result}")
    if result != 10:
        raise TestFailure(f"Test 3 failed: expected 10, got {result}")
    
    await RisingEdge(dut.clk)
    
    # Test Case 4: Multiple producers/consumers, verify all pairs checked
    # Producers: [(1,1), (100,100)] - second one is expensive
    # Consumers: [(50,5), (200,10)]
    # Best: Producer 0 + Consumer 1: profit/day=199, days=9, total=1791
    # Also check Producer 0 + Consumer 0: profit/day=49, days=4, total=196
    # Producer 1 is too expensive for both
    
    dut.num_producers.value = 2
    dut.num_consumers.value = 2
    dut.producer_prices[0].value = 1
    dut.producer_dates[0].value = 1
    dut.producer_prices[1].value = 100
    dut.producer_dates[1].value = 100
    dut.consumer_prices[0].value = 50
    dut.consumer_dates[0].value = 5
    dut.consumer_prices[1].value = 200
    dut.consumer_dates[1].value = 10
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Timeout waiting for done signal")
    
    result = dut.max_profit.value
    print(f"Test 4 - Expected: 1791, Got: {result}")
    if result != 1791:
        raise TestFailure(f"Test 4 failed: expected 1791, got {result}")
    
    # Print summary
    print("
=== Test Summary ===")
    print("4/4 tests passed")
