import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.types import LogicArray
import numpy as np

@cocotb.test()
async def test_pirates(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        (1, [546], -1),    # Invalid n=1
        (3, [1,2,3], 3),   # Sample case
        (5, [1,1,2,4,4], 6), # Adapted from input 5
        (15, [10]*15, 34), # Max moves for n=15
        (2, [707,629], -1) # Invalid even n
    ]
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    for (n_val, a_vals, expected) in test_cases:
        # Setup inputs
        dut.start.value = 0
        dut.n_in.value = n_val
        for i in range(15):
            if i < len(a_vals):
                dut.a[i].value = a_vals[i]
            else:
                dut.a[i].value = 0
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        # Check result
        actual = dut.result.value.signed_integer
        if actual == expected:
            passed += 1
            dut._log.info(f"Test passed: n={n_val} result={actual}")
        else:
            dut._log.error(f"Test failed: n={n_val} got {actual}, expected {expected}")
        await RisingEdge(dut.clk)
        dut._log.info(f"{passed}/{len(test_cases)} tests passed")
