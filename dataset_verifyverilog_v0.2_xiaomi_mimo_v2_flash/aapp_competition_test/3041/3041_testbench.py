import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_ticket_optimizer(dut):
    """Test ticket optimizer with multiple trip sequences"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_trip.value = 0
    dut.compute.value = 0
    dut.trip_zone.value = 0
    dut.trip_time.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to process a trip sequence
    async def run_test(trips, expected_cost, test_name):
        dut._log.info(f"Running {test_name}")
        
        # Reset for new test
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Load each trip
        for zone, time in trips:
            dut.trip_zone.value = zone
            dut.trip_time.value = time
            dut.load_trip.value = 1
            await RisingEdge(dut.clk)
            dut.load_trip.value = 0
            await RisingEdge(dut.clk)
        
        # Compute
        dut.compute.value = 1
        for _ in range(100):  # Wait for completion
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            raise TestFailure(f"{test_name}: did not complete in 100 cycles")
        
        dut.compute.value = 0
        
        # Check result
        result = int(dut.min_cost.value)
        dut._log.info(f"{test_name}: Expected {expected_cost}, Got {result}")
        
        if result != expected_cost:
            raise TestFailure(f"{test_name}: Expected {expected_cost}, Got {result}")
    
    # Test 1: Two trips in same ticket validity period
    # Trip1: zone 1, time 4
    # Trip2: zone 2, time 5
    # Optimal: Buy ticket [1,2] costing 2+|1-2|=3 coupons, but wait...
    # Actually: zone 0 start, trip to 1, then to 2
    # Buy ticket [1,2] covering both trips: cost 3
    # But initial position is zone 0, so first trip needs ticket [0,1] or [0,2]
    # [0,2] covers all: cost 2+2=4 (optimal)
    await run_test([(1, 4), (2, 5)], 4, "Test 1: Two trips close together")
    
    # Test 2: Two trips far apart in time
    # Trip1: zone 1, time 4
    # Trip2: zone 2, time 10005 (too late, new ticket needed)
    # Need two tickets: [0,1] cost 2+1=3, [1,2] cost 2+1=3, total 6
    # Or [0,2] cost 4 for first, [1,2] cost 3 for second? But ticket invalid
    # Actually: [0,1] for first, [1,2] for second: 3+3=6
    # Or [0,2] for first (4), then [0,2] for second (4) = 8
    # So 6 is minimal
    await run_test([(1, 4), (2, 10005)], 6, "Test 2: Tickets expire")
    
    # Test 3: Three trips
    # Trip1: zone 1, time 4
    # Trip2: zone 2, time 10
    # Trip3: zone 0, time 15
    # All within 256 cycles (valid period)
    # One ticket [0,2] covers all: cost 2+2=4
    await run_test([(1, 4), (2, 10), (0, 15)], 4, "Test 3: Three trips")
    
    # Test 4: Edge case - single trip
    await run_test([(5, 10)], 2+5, "Test 4: Single trip")
    
    # Test 5: No trips
    await run_test([], 0, "Test 5: No trips")
    
    dut._log.info("All tests passed!")