import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_rect_ext(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await Timer(15, units='ns')

    # Adapted test cases (original inputs scaled)
    test_cases = [
        # Input 1 (original required 1 extension)
        {'a':3, 'b':3, 'h':2, 'w':4, 'n':4, 'factors':[10,5,4,2], 'exp':1},
        # Input 2 (already fits)
        {'a':3, 'b':3, 'h':3, 'w':3, 'n':5, 'factors':[5,4,3,2,2], 'exp':0},
        # Input 3 (impossible)
        {'a':5, 'b':5, 'h':1, 'w':2, 'n':3, 'factors':[3,2,2], 'exp':31},
        # Input 4 (needs all 3 extensions)
        {'a':3, 'b':4, 'h':1, 'w':1, 'n':3, 'factors':[3,3,2], 'exp':3},
        # Edge case: minimal factors needed
        {'a':20, 'b':20, 'h':5, 'w':5, 'n':2, 'factors':[4,2], 'exp':2}
    ]

    passed = 0
    for case in test_cases:
        # Initialize inputs
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.a.value = case['a']
        dut.b.value = case['b']
        dut.h.value = case['h']
        dut.w.value = case['w']
        dut.num_factors.value = case['n']
        for i in range(16):
            dut.factors[i].value = case['factors'][i] if i < len(case['factors']) else 0
        
        # Reset sequence
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        actual = dut.min_count.value
        if actual == case['exp']:
            passed += 1
        else:
            dut._log.error(f"Case failed: Expected {case['exp']}, got {actual}
                a={case['a']}, b={case['b']}, h={case['h']}, w={case['w']}, factors={case['factors']}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")