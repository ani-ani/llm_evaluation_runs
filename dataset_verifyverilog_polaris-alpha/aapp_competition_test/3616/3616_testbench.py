import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_allergen(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Test cases: (k, [D1,D2,D3,D4], expected_T)
    test_data = [
        (3, [2,2,2,0], 5),  # Original 1st test case
        (5, [1,4,2,5], 10), # Modified: only 4 allergens used
        (2, [3,3,0,0], 4),  # Additional case: 2 allergens
        (4, [1,1,1,1], 1)   # Minimal case
    ]
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    for (k_val, Ds, expected) in test_data:
        dut.start.value = 0
        dut.k.value = k_val
        dut.D1.value = Ds[0]
        dut.D2.value = Ds[1]
        dut.D3.value = Ds[2]
        dut.D4.value = Ds[3]
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait 3 cycles for result
        for _ in range(3):
            await RisingEdge(dut.clk)
        if dut.done.value == 1 and dut.T.value == expected:
            passed += 1
            dut._log.info(f"Passed: k={k_val} Ds={Ds} → T={dut.T.value}")
        else:
            dut._log.error(f"Failed: k={k_val} Ds={Ds} → T={dut.T.value} (expected {expected})")
    dut._log.info(f"{passed}/{len(test_data)} tests passed")
    assert passed == len(test_data)