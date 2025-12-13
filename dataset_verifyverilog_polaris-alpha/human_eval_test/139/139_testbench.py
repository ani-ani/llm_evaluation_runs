import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

async def reset(dut):
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    dut.start.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_special_factorial(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset(dut)

    test_cases = [
        (1, 1),
        (4, 288),
        (5, 34560),
        (7, 125411328000),
    ]
    passed = 0

    for n_val, expected in test_cases:
        dut.start.value = 0
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.done.value = 0
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val}, result={dut.result.value}")
        else:
            dut._log.error(f"FAIL: n={n_val}, got={dut.result.value}, expected={expected}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Tests passed: {passed}/{len(test_cases)}")
    assert passed == len(test_cases), f"Failed {len(test_cases)-passed} tests"
