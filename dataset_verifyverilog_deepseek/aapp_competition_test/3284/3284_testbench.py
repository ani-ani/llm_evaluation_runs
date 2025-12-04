import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from math import gcd

@cocotb.test()
async def test_coprime_counter(dut):
    # Create clock generator
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Define scaled test cases
    test_cases = [
        (1, 5, 1, 5, 19),   # Original test case (scaled matches original)
        (12, 12, 1, 12, 4),   # Original test case linear x point
        (1, 8, 1, 8, 42)    # New scaled test case
    ]
    
    passed = 0
    
    for a, b, c, d, expected in test_cases:
        # Reset device
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        dut.d.value = d
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 15x15=225 cycles)
        for _ in range(230):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.count.value == expected:
            passed += 1
            dut._log.info(f"Test passed: {a}-{b}x{c}-{d} = {dut.count.value}")
        else:
            dut._log.error(f"TEST FAILED: Input {a}-{b}x{c}-{d} | Received: {dut.count.value}, Expected: {expected}")
        
        # Small delay before next test
        await Timer(10, units="ns")
    
    dut._log.info(f"Test summary: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"