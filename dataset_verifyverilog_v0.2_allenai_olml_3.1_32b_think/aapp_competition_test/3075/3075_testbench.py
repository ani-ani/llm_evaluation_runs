import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_gas_trip_optimizer(dut):
    """Test the gas station optimizer module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Gas Station Optimizer Tests ===")
    
    # Test 1: Sample Input 1
    # Stations: (1,10), (2,100), (11,5) - sorted by distance
    # Tank: 10, Expected: 10.0
    print("
Test 1: Basic case (should be 10.0)")
    dut.num_stations.value = 3
    dut.tank_capacity.value = 10
    # Station 0: dist=1, cost=10.0
    dut.station_dist[0].value = 1
    dut.station_cost[0].value = 10 << 16  # 10.0 * 65536
    # Station 1: dist=2, cost=100.0
    dut.station_dist[1].value = 2
    dut.station_cost[1].value = 100 << 16  # 100.0 * 65536
    # Station 2: dist=11, cost=5.0
    dut.station_dist[2].value = 11
    dut.station_cost[2].value = 5 << 16   # 5.0 * 65536
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 100 cycles)
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.cancel.value:
        print(f"Result: CANCEL (unexpected)")
        assert False, "Test 1 failed: Got CANCEL instead of cost"
    else:
        cost = dut.total_cost.value
        cost_float = cost / 65536.0
        print(f"Result: {cost_float} (Q16.16: {cost})")
        assert abs(cost_float - 10.0) < 0.01, f"Test 1 failed: Expected 10.0, got {cost_float}"
    
    await RisingEdge(dut.clk)
    await Timer(10, units='ns')
    
    # Test 2: Sample Input 2 (impossible)
    # Stations: (1,10), (2,100), (13,5) - gap from 2 to 13 is 11 > tank 10
    print("
Test 2: Impossible case (should be CANCEL)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_stations.value = 3
    dut.tank_capacity.value = 10
    dut.station_dist[0].value = 1
    dut.station_cost[0].value = 10 << 16
    dut.station_dist[1].value = 2
    dut.station_cost[1].value = 100 << 16
    dut.station_dist[2].value = 13
    dut.station_cost[2].value = 5 << 16
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.cancel.value:
        print("Result: CANCEL (expected)")
        assert True
    else:
        cost = dut.total_cost.value
        print(f"Result: {cost/65536.0} (unexpected)")
        assert False, "Test 2 failed: Expected CANCEL"
    
    await RisingEdge(dut.clk)
    await Timer(10, units='ns')
    
    # Test 3: Sample Input 3
    # Stations: (1,1.0), (10,5.0), (12,3.0) - sorted
    # Tank: 10, Expected: 6.0
    print("
Test 3: Mixed costs (should be 6.0)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_stations.value = 3
    dut.tank_capacity.value = 10
    # Station 0: dist=1, cost=1.0
    dut.station_dist[0].value = 1
    dut.station_cost[0].value = 1 << 16  # 1.0
    # Station 1: dist=10, cost=5.0
    dut.station_dist[1].value = 10
    dut.station_cost[1].value = 5 << 16  # 5.0
    # Station 2: dist=12, cost=3.0
    dut.station_dist[2].value = 12
    dut.station_cost[2].value = 3 << 16  # 3.0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.cancel.value:
        print(f"Result: CANCEL (unexpected)")
        assert False, "Test 3 failed: Got CANCEL"
    else:
        cost = dut.total_cost.value
        cost_float = cost / 65536.0
        print(f"Result: {cost_float} (Q16.16: {cost})")
        assert abs(cost_float - 6.0) < 0.01, f"Test 3 failed: Expected 6.0, got {cost_float}"
    
    await RisingEdge(dut.clk)
    await Timer(10, units='ns')
    
    # Test 4: Single station (start to destination)
    print("
Test 4: Single station at distance 5, cost 7.5")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_stations.value = 1
    dut.tank_capacity.value = 20
    dut.station_dist[0].value = 5
    # 7.5 * 65536 = 491520 = 0x00078000
    dut.station_cost[0].value = 491520
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.cancel.value:
        print(f"Result: CANCEL (unexpected)")
        assert False, "Test 4 failed"
    else:
        cost = dut.total_cost.value
        cost_float = cost / 65536.0
        print(f"Result: {cost_float}")
        assert abs(cost_float - 7.5) < 0.01, f"Test 4 failed: Expected 7.5, got {cost_float}"
    
    await RisingEdge(dut.clk)
    await Timer(10, units='ns')
    
    # Test 5: Fill at each station when cheaper ahead but far
    print("
Test 5: Must fill at multiple stations")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_stations.value = 4
    dut.tank_capacity.value = 10
    dut.station_dist[0].value = 0
    dut.station_cost[0].value = 10 << 16
    dut.station_dist[1].value = 5
    dut.station_cost[1].value = 8 << 16
    dut.station_dist[2].value = 9
    dut.station_cost[2].value = 6 << 16
    dut.station_dist[3].value = 15
    dut.station_cost[3].value = 5 << 16
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.cancel.value:
        print(f"Result: CANCEL")
        assert False, "Test 5 failed"
    else:
        cost = dut.total_cost.value
        cost_float = cost / 65536.0
        print(f"Result: {cost_float}")
        # Expected: fill 5L at 10 (cost 50), then 4L at 8 (cost 32), total 82 - wait
        # At 0: 10 cost, tank 10, need to reach 5 (5km) -> buy 5L = 50, fuel left 5
        # At 5: 8 cost, tank 10, current fuel 5, need 4L to reach 9 (4km), but 6 cost ahead is cheaper
        # Actually: at 0, cheaper is 8 at 5, so buy just 5L (to reach 5) = 50
        # At 5: cheaper is 5 at 15, but 10km away, tank 10 -> must fill full 10L total, have 5, buy 5 more = 40, total 90
        # Wait, distance 9 is 4km, cost 6; destination is 6km away, cost 5
        # At 5: cheaper exists (5 at 15), need 10L to reach, have 5L, buy 5L = 40
        # At 9: cost 6, tank 10, current fuel 1L (from 5L - 4km), need 6L to reach 15 = 36
        # Total: 50 + 36 = 86
        expected = 86.0
        assert abs(cost_float - expected) < 0.01, f"Test 5 failed: Expected {expected}, got {cost_float}"
    
    print("
=== All tests completed ===")
