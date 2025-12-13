import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_pita_pizza(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    # Define test cases (scaled to cents)
    test_cases = [
        (10000, 2000, 1000, [(0, 10), (1, 8), (2, 6), (3, 4), (4, 2), (5, 0)]),  # Original $100.00 case
        (5000, 200, 300, [(10, 10), (13, 8), (16, 6), (19, 4), (22, 2), (25, 0)]),  # New scaled case
        (300, 150, 150, [(0, 2), (2, 0)]),  # Small values
        (1000, 500, 100, [(0, 10), (2, 0)]),  # Values with exact divisions
        (999, 333, 333, [(3, 0)])  # Edge case with single solution
    ]
    
    passed = 0
    total_tests = len(test_cases)
    
    for idx, (tp, p1, p2, expected) in enumerate(test_cases):
        # Reset and initialize
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Apply inputs
        dut.total_profit.value = tp
        dut.pita_profit.value = p1
        dut.pizza_profit.value = p2
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect results
        results = []
        timeout = 200 # More than 101+ cycles
        
        while True:
            await RisingEdge(dut.clk)
            timeout -= 1
            
            if dut.valid.value == 1:
                results.append((dut.pita_count.value.integer, dut.pizza_count.value.integer))
            
            if timeout == 0 or dut.done.value == 1:
                break
        
        # Check if all expected found and no extras
        if results == expected:
            passed += 1
        else:
            dut._log.error(f"Test case {idx} failed: Input {tp}/{p1}/{p2}")
            dut._log.error(f"Expected: {expected}, Got: {results}")
    
    dut._log.info(f"{passed}/{total_tests} tests passed")