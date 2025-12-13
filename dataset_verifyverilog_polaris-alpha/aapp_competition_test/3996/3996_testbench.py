import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

MOD = 10**9+7
INV3 = 333333336
INV2 = 500000004

@cocotb.test()
async def test_cup(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    test_cases = [
        (1, [2], 1, 2),  # Original: 2 → 1/2
        (3, [1,1,1], 0, 1),  # All odds → 0/1
        (1, [4], (pow(2,4,MOD)*INV2%MOD + 1)*INV3%MOD, pow(2,4,MOD)*INV2%MOD)
    ]
    passed = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0; dut.start.value = 0; await RisingEdge(dut.clk)
    dut.rst_n.value = 1; await RisingEdge(dut.clk)
    for i, (k, arr, exp_p, exp_q) in enumerate(test_cases):
        # Load inputs
        dut._log.info(f"Starting test case {i}")
        dut.k.value = k
        for idx in range(8):  # Pad list to 8 elements
            val = arr[idx] if idx < len(arr) else 0
            dut.a[idx].value = val if idx < len(arr) else 0
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        cycles_waited = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            cycles_waited += 1
            if cycles_waited > 20 + k:
                assert False, "Timeout waiting for done"
        # Verify outputs
        assert dut.p.value == exp_p, f"Test {i} failed: p={dut.p.value} vs expected {exp_p}"
        assert dut.q.value == exp_q, f"Test {i} failed: q={dut.q.value} vs expected {exp_q}"
        passed += 1
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
