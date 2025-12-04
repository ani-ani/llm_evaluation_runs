import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def train_route_test(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (cities, adj_matrix, expected_flights, expected_airports)
    test_cases = [
        # Sample Input 1: 4 cities complex DAG
        (4, 0x1A, 1, 0b1111), # adj_matrix: 0b0001_1010 (1->2,1->3,2->4,3->4)
        # Sample Input 2: 4 cities linear chain
        (4, 0x12, 0, 0b0000), # adj_matrix: 0b0001_0010 (1->2->3->4)
        # Additional test case: 2 disconnected clusters
        (4, 0x88, 3, 0b1111)  # adj_matrix: 0b1000_1000 (1->4, 2->4)
    ]
    
    passed = 0
    dut._log.info("Starting test")
    
    for (n, adj, exp_flights, exp_airports) in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Apply inputs
        dut.num_cities.value = n
        dut.adj_matrix.value = adj
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        timeout = 0
        while not dut.done.value and timeout < 20:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 20:
            dut._log.error("Test timed out")
            continue
        
        # Check results
        success = True
        if dut.min_flights.value != exp_flights:
            dut._log.error(f"Flights error: Got {dut.min_flights.value}, expected {exp_flights}")
            success = False
        if dut.airports.value != exp_airports:
            dut._log.error(f"Airports error: Got {bin(dut.airports.value)}, expected {bin(exp_airports)}")
            success = False
        
        if success:
            passed += 1
            dut._log.info(f"Test passed! n={n} adj={hex(adj)}")
    
    dut._log.info(f"RESULT: {passed}/{len(test_cases)} tests passed")