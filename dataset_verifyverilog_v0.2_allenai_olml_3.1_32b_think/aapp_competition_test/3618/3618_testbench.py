import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

MOD = 998244353

def python_model(n):
    if n == 1:
        return 10
    
    # Calculate powers modulo MOD
    p5 = pow(5, n, MOD)
    p5_minus_1 = pow(5, n-1, MOD)
    
    if n % 2 == 1: # Odd
        comp = (1000 * p5) % MOD
    else: # Even
        # comp = 1000 * p5 - 4 * 5^(n-1)
        # Python handles negative mod correctly
        comp = (1000 * p5 - 4 * p5_minus_1) % MOD
    
    # Pairs = comp * (comp - 1) // 2
    res = (comp * (comp - 1)) // 2
    return res % MOD

@cocotb.test()
async def test_best_friends(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [1, 2, 3, 4, 5, 8, 10, 12, 14, 16]
    
    passed = 0
    total = len(test_cases)
    
    for n in test_cases:
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            
        # Read result
        hw_result = int(dut.result.value)
        expected = python_model(n)
        
        print(f"n={n}: HW={hw_result}, Exp={expected}")
        assert hw_result == expected, f"Mismatch for n={n}"
        passed += 1
        await RisingEdge(dut.clk)
        
    print(f"
{passed}/{total} tests passed")