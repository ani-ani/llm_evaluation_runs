import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_flight_scheduler(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await Timer(15, units="ns")
    
    test_cases = [
        # Sample input 1 (adapted)
        {
            "k": 5,
            "flights": [
                (1, 1, 0, 5000),
                (2, 2, 0, 6000),
                (3, 2, 0, 5500),
                (8, 0, 2, 6500),
                (9, 0, 1, 7000),
                (15, 0, 2, 9000)
            ],
            "expected": 24500,
        },
        # Sample input 2 (impossible case)
        {
            "k": 5,
            "flights": [
                (1, 2, 0, 5000),
                (2, 1, 0, 4500),
                (2, 1, 0, 3000),
                (8, 0, 1, 6000)
            ],
            "expected": -1,
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for case in test_cases:
        # Reset and initialize
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        
        # Load test data
        dut.k_days.value = case["k"]
        flights = case["flights"]
        num_flights = len(flights)
        dut.num_flights.value = num_flights
        
        # Zero-fill unused flights
        for i in range(16):
            if i < num_flights:
                d, f, t, c = flights[i]
                dut.flight_days[i].value = d
                dut.flight_from[i].value = f
                dut.flight_to[i].value = t
                dut.flight_cost[i].value = c
            else:
                dut.flight_days[i].value = 0
                dut.flight_from[i].value = 0
                dut.flight_to[i].value = 0
                dut.flight_cost[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 32 cycles)
        for _ in range(40):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        expected = case["expected"]
        if expected == -1:
            if dut.impossible.value != 1:
                dut._log.error(f"Test failed: Expected impossible but got cost={dut.min_cost.value}")
            else:
                passed += 1
        else:
            if int(dut.min_cost.value) == expected and dut.impossible.value == 0:
                passed += 1
            else:
                dut._log.error(f"Test failed: Expected {expected}, got {dut.min_cost.value} impossible={dut.impossible.value}")
    
    dut._log.info(f"{passed}/{total} tests passed")
