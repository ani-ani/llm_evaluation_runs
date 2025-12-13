import cocotb
from cocotb.triggers import RisingEdge
import random

@cocotb.test()
async def test_house_counter(dut):
    cocotb.start_soon(cocotb.clock.Clock(dut.clk, 10, units='ns').start())
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    # Test cases (L,R,expected)
    test_cases = [(30, 70, 11), (66, 69, 2), (100, 999, 0)] + [(1,1000, random.randint(0,1000)) for _ in range(2)]
    passed = 0
    for L_val, R_val, expected in test_cases:
        dut.L.value = L_val
        dut.R.value = R_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
        if int(dut.count.value) == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: L={L_val} R={R_val}
              Got {dut.count.value}, expected {expected}")
        await RisingEdge(dut.clk)
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
