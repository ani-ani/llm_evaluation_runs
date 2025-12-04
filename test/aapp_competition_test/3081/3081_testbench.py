import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_planes(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test Case 1: Requires 2 planes (sample input 1)
    test1_inspect = [1, 1] + [0]*2
    test1_flight_times = [ [0,1,0,0], [1,0,0,0], [0,0,0,0], [0,0,0,0] ]
    test1_flights = { 's': [0,1], 'f': [1,0], 't': [1,1] }
    expected1 = 2

    # Test Case 2: Requires 1 plane (sample input 2)
    test2_inspect = [1, 1] + [0]*2
    test2_flight_times = test1_flight_times
    test2_flights = { 's': [0,1], 'f': [1,0], 't': [1,3] }
    expected2 = 1

    # Test Case 3: Extended example (requires 3 planes)
    test3_inspect = [5, 2, 7, 3]
    test3_flight_times = [ [0, 10,15,20], [10,0,25,30], [15,25,0,5], [20,30,5,0] ]
    test3_flights = {
        's': [0,1,2,3],
        'f': [1,2,3,0],
        't': [100, 120, 150, 200]
    }
    expected3 = 3

    for (inspect_t, flight_mtx, flights, exp) in [ 
        (test1_inspect, test1_flight_times, test1_flights, expected1),
        (test2_inspect, test2_flight_times, test2_flights, expected2),
        (test3_inspect, test3_flight_times, test3_flights, expected3) 
    ]:
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inspection times
        for i in range(4):
            dut.inspect_time[i].value = inspect_t[i] if i < len(inspect_t) else 0
        
        # Load flight matrix
        for i in range(4):
            for j in range(4):
                val = flight_mtx[i][j] if i < len(flight_mtx) and j < len(flight_mtx[i]) else 0
                dut.flight_times[i][j].value = val
        
        # Load flight requests
        for i in range(4):
            s = flights['s'][i] if i < len(flights['s']) else 0
            f = flights['f'][i] if i < len(flights['f']) else 0
            t = flights['t'][i] if i < len(flights['t']) else 0
            dut.flight_s[i].value = s
            dut.flight_f[i].value = f
            dut.flight_t[i].value = t
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 110 cycles)
        for _ in range(110):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        assert dut.done.value == 1, "Timeout waiting for done"
        assert dut.plane_count.value == exp, f"Expected {exp} planes, got {dut.plane_count.value}"
    
    dut._log.info("3/3 tests passed")