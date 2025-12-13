import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_smoothie(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        (1000, 3000, 1000, 533.3333333),
        (1000, 500, 1000, 0.0),
        (100, 500, 300, 400.0),
        (500, 300, 1000, 0.0),  # W < C but D > W
        (50, 200, 100, 150.0)   # 200-50=150
    ]

    passed = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1

    for D, W, C, expected in test_cases:
        dut.d.value = D
        dut.w.value = W
        dut.c.value = C
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await ClockCycles(dut.clk, 16)
        if not dut.done.value:
            await RisingEdge(dut.done)
        result_fixed = dut.result.value.signed_integer / 256.0  # Q24.8 conversion
        if abs(result_fixed - expected) < 0.1 or 
           (abs(result_fixed - expected)/expected < 1e-4 if expected != 0 else True):
            passed += 1
        else:
            dut._log.error(
                f"Failed: D={D}, W={W}, C={C} => {result_fixed:.6f}, expected {expected:.6f}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)