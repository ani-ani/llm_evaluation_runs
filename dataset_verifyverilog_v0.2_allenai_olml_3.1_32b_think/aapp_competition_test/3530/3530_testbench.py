import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_roller_coaster_fun(dut):
    """Test roller coaster fun maximization with multiple scenarios"""
    
    # Setup clock and reset
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize inputs
    dut.rst_n.value = 1
    dut.start.value = 0
    
    # Initialize coaster arrays
    for i in range(8):
        dut.coaster_a[i].value = 0
        dut.coaster_b[i].value = 0
        dut.coaster_t[i].value = 0
    
    dut.time_budget.value = 0
    
    # Apply reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    async def run_test(num, coasters, time_budget, expected_fun):
        """Run a single test case"""
        # Load coaster data
        for i in range(8):
            if i < len(coasters):
                dut.coaster_a[i].value = coasters[i][0]
                dut.coaster_b[i].value = coasters[i][1]
                dut.coaster_t[i].value = coasters[i][2]
            else:
                dut.coaster_a[i].value = 0
                dut.coaster_b[i].value = 0
                dut.coaster_t[i].value = 0
        
        dut.time_budget.value = time_budget
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 200
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        # Read result
        result = int(dut.max_fun.value)
        
        print(f"Test {num}: Time={time_budget}, Expected={expected_fun}, Got={result}")
        assert result == expected_fun, f"Test {num} failed: expected {expected_fun}, got {result}"
        
        # Wait one more cycle before next test
        await RisingEdge(dut.clk)
    
    # Test 1: Sample input from problem (adapted)
    # Coaster 0: a=5, b=0, t=5 (all rides fun=5)
    # Coaster 1: a=7, b=0, t=7 (all rides fun=7)
    # time=88: Can take many rides, but time_budget capped at 256, expected=141
    # time=5: Take 1 ride of coaster 0, fun=5
    # time=6: Still only 1 ride of coaster 0, fun=5  
    # time=7: Take 1 ride of coaster 1, fun=7
    await run_test(1, [(5,0,5), (7,0,7), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0)], 88, 141)
    await run_test(2, [(5,0,5), (7,0,7), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0)], 5, 5)
    await run_test(3, [(5,0,5), (7,0,7), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0)], 6, 5)
    await run_test(4, [(5,0,5), (7,0,7), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0)], 7, 7)
    
    # Test 2: Coaster with diminishing returns
    # Coaster: a=100, b=3, t=2
    # Ride 1: fun = 100 - 0 = 100
    # Ride 2: fun = 100 - 1*3 = 97
    # Ride 3: fun = 100 - 4*3 = 88
    # Ride 4: fun = 100 - 9*3 = 73
    # Ride 5: fun = 100 - 16*3 = 52
    # Ride 6: fun = 100 - 25*3 = 25
    # Ride 7: fun = 100 - 36*3 = -8 (negative, stop)
    # So valid rides: 1,2,3,4,5,6 with fun=[100,97,88,73,52,25]
    # time=2: ride 1, fun=100
    # time=3: ride 1 + half? Can't. But time_budget is integer.
    # Wait, in problem time=2 means 1 ride (time=2).
    # time=3: Can take 1 ride (time=2), remainder=1 wasted. fun=100
    # time=4: Can take 2 rides (time=4), fun=100+97=197
    # time=5: 2 rides (time=4), remainder=1. fun=197
    # time=100: many rides
    await run_test(5, [(100,3,2), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0)], 2, 100)
    await run_test(6, [(100,3,2), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0)], 3, 100)
    await run_test(7, [(100,3,2), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0)], 4, 197)
    await run_test(8, [(100,3,2), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0)], 5, 197)
    
    # Edge case: Zero fun
    await run_test(9, [(0,0,5), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0)], 10, 0)
    
    # Edge case: Single ride with high cost
    await run_test(10, [(255,0,255), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0), (0,0,0)], 255, 255)
    
    print("All 10 tests passed!")
