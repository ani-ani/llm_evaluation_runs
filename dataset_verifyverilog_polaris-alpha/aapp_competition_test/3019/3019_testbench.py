import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_revenue(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Prime factors lookup helper (implementation for testbench)
    def count_distinct_prime_factors(n):
        if n < 2: return 0
        factors = set()
        i = 2
        while i*i <= n:
            if n % i == 0:
                factors.add(i)
                while n % i == 0:
                    n //= i
            i += 1
        if n > 1:
            factors.add(n)
        return len(factors)
    
    # Test cases (adapted N <=5)
    test_cases = [
        {"N": 1, "S": [1], "EXPECTED": 0},
        {"N": 3, "S": [4,7,8], "EXPECTED": 3},
        {"N": 5, "S": [2,3,4,5,8], "EXPECTED": 5}
    ]
    
    passed = 0
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for case in test_cases:
        # Apply test case inputs
        dut.N.value = case["N"]
        for i in range(5):
            if i < len(case["S"]):
                getattr(dut, f'S{i}').value = case["S"][i]
            else:
                getattr(dut, f'S{i}').value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.max_rev.value == case["EXPECTED"]:
            passed += 1
        else:
            dut._log.error(f"Test failed: N={case['N']}, S={case['S']} => {dut.max_rev.value}, expected {case['EXPECTED']}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")