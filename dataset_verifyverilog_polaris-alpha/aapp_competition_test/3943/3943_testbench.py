import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_card_score(dut):
    # Generate clock (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Function to perform reset
    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    await reset()
    
    # Scaled test cases (original values <= 255, exclude string verification)
    test_cases = [
        (4, 0, 16),
        (0, 4, -16),
        (8, 6, 46),
        (1, 1, 0),
        (38, 5, 1431),
        (2, 3, -1),
        (4, 2, 14)
    ]
    
    # Custom function to compute expected score (copied from Python logic)
    def compute_score(a, b):
        if a == 0: return -b*b
        if b == 0: return a*a
        if b == 1: return a*a-1
        ans = -float('inf')
        for i in range(2, min(a+2, b+1)+1):
            v1 = (a+2-i)**2 + (i-2)
            quo = b // i
            rem = b % i
            v2 = rem*(quo+1)**2 + (i-rem)*(quo**2)
            if (v1 - v2) > ans: ans = v1 - v2
        return ans
    
    passed = 0
    for (a_val, b_val, _) in test_cases:
        # Calculate expected from Python function (in case of scaled vals)
        expected = compute_score(a_val, b_val)
        
        dut.start.value = 0
        dut.a.value = a_val
        dut.b.value = b_val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 20 cycles)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1: break
        else:
            dut._log.error("Timeout waiting for done")
        
        # Verify output
        score = dut.max_score.value.signed_integer
        if score == expected:
            passed +=1
            dut._log.info(f"Test passed: {a_val}, {b_val} -> {score}")
        else:
            dut._log.error(f"Test FAILED: {a_val}, {b_val} Expected {expected}, got {score}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")