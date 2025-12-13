import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_min_energy(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k_query.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    # Test case 1: n=4, a=[2,3,5,7] (a1=2, a2=3, a3=5, a4=7)
    dut.n.value = 4  # 3-bit value for n=4
    dut.a0.value = 2; dut.a1.value = 3; dut.a2.value = 5; dut.a3.value = 7
    dut.a4.value = 0; dut.a5.value = 0; dut.a6.value = 0; dut.a7.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # Wait until ready
    while not dut.ready.value:
        await RisingEdge(dut.clk)
    # Query test cases
    test_queries = [
        (2, 3), # k=2 → a2=3
        (3, 5), # k=3 → a3=5
        (5, 8), # min(2+6=8? 3+5=8?)
        (6, 10), # 3+3+5? Actual sample output is 10
        (8, 13)  # sample output
    ]
    passed = 0
    for k, expected in test_queries:
        dut.k_query.value = k
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)  # Wait 2 cycles for result
        if dut.valid.value and dut.min_energy.value == expected:
            passed += 1
        else:
            dut._log.error(f"Failed k={k}: got {dut.min_energy.value}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_queries)} tests passed")
    # Test case 2: n=1, a0=10 (k=1,2,100 simplified to k=1,2,16)
    await RisingEdge(dut.clk)
    dut.n.value = 1
    dut.a0.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while not dut.ready.value:
        await RisingEdge(dut.clk)
    test_queries2 = [(1, 10), (2, 20), (16, 160)]  # 16*10=160
    for k, expected in test_queries2:
        dut.k_query.value = k
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        if dut.valid.value and dut.min_energy.value == expected:
            passed += 1
        else:
            dut._log.error(f"Failed k={k}: got {dut.min_energy.value}, expected {expected}")
    dut._log.info(f"Total: {passed}/{len(test_queries)+len(test_queries2)} passed")