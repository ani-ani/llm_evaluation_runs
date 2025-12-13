import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
import random

MOD = 1000000007

@cocotb.test()
async def test_permutation(dut):
    cocotb.start_soon(cocotb.clock.Clock(dut.clk, 10, units="ns").start())
    test_cases = [
        (2, [1-1, 2-1], 2),  # Original n=2 case scaled to 0-index
        (5, [3-1,4-1,5-1,1-1,2-1], 1),  # Original n=5 scaled (pad with 0)
        (4, [2-1,1-1,4-1,3-1], 2)  # Custom 4-cycle test
    ]
    passed = 0
    for n_val, t_arr, expected in test_cases:
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        # Load inputs
        dut.n.value = n_val
        for i in range(8):
            if i < len(t_arr):
                getattr(dut, f"t_{i}").value = t_arr[i]
            else: 
                getattr(dut, f"t_{i}").value = 0
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        # Verify result
        actual = dut.result.value.integer % MOD
        if actual == expected:
            passed += 1
            dut._log.info(f"Test passed: n={n_val} → {actual}")
        else:
            dut._log.error(f"Test failed: n={n_val} expect={expected} got={actual}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
assert passed == len(test_cases)