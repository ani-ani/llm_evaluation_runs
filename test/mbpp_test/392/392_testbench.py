import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_dynamic_max(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        (2, 2),   # Original Test 3
        (10, 12), # Original Test 2
        (5, 5),   # Added case
        (7, 8),   # Hand calculated: max(7, f(3)+f(2)+f(1)+f(1) = 3+2+1+1=7)
        (16, 29)  # Hand calculated
    ]

    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for (n_val, expected) in test_cases:
        # Apply inputs
        dut.n_in.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check result
        result = dut.result.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} result={result}")
        else:
            dut._log.error(f"FAIL: n={n_val} got {result}, expected {expected}")
        
        # Insert idle cycle
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)