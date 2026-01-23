import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_min_cost_calculator(dut):
    # Create a clock generator (50MHz)
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_factors.value = 0
    for i in range(8):
        dut.prime_factors[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: K = 12 (factors 2, 3, 2)
    # Input: 020302 -> primes [2, 3, 2]
    dut.num_factors.value = 3
    dut.prime_factors[0].value = 2
    dut.prime_factors[1].value = 3
    dut.prime_factors[2].value = 2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while dut.done.value == 0 and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.done.value == 0:
        raise TestFailure("Test Case 1: Did not finish within timeout")
    
    result = int(dut.min_cost.value)
    print(f"Test Case 1: K=12. Expected 7, Got {result}")
    if result != 7:
        raise TestFailure(f"Test Case 1 Failed: Expected 7, Got {result}")

    await RisingEdge(dut.clk)

    # Test Case 2: K = 143 (factors 13, 11)
    dut.num_factors.value = 2
    dut.prime_factors[0].value = 13
    dut.prime_factors[1].value = 11
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.done.value == 0:
        raise TestFailure("Test Case 2: Did not finish within timeout")
    
    result = int(dut.min_cost.value)
    print(f"Test Case 2: K=143. Expected 24, Got {result}")
    if result != 24:
        raise TestFailure(f"Test Case 2 Failed: Expected 24, Got {result}")

    await RisingEdge(dut.clk)

    # Test Case 3: K = 11 (factor 11)
    dut.num_factors.value = 1
    dut.prime_factors[0].value = 11
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.done.value == 0:
        raise TestFailure("Test Case 3: Did not finish within timeout")
    
    result = int(dut.min_cost.value)
    print(f"Test Case 3: K=11. Expected 12, Got {result}")
    if result != 12:
        raise TestFailure(f"Test Case 3 Failed: Expected 12, Got {result}")
        
    print("All tests passed!")
