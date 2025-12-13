import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
import random
import math

@cocotb.test()
async def test_aesthetic_path(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Test cases (n, expected)
    test_cases = [
        (1, 1), (4, 2), (5, 5), 
        (2, 2), (3, 3), (6, 1), 
        (7, 7), (8, 2), (9, 3), 
        (12, 1), (15, 1), (16, 2)
    ]
    
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for n_val, expected in test_cases:
        dut.start.value = 1
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 100 cycles)
        for _ in range(100):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure("Timeout waiting for done")
        
        actual = dut.result.value.integer
        if actual == expected:
            passed += 1
        else:
            dut._log.error(f"FAIL: n={n_val} => {actual}, expected {expected}")
        await RisingEdge(dut.clk)  # Clear done
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    if passed != len(test_cases):
        raise TestFailure("Some tests failed")