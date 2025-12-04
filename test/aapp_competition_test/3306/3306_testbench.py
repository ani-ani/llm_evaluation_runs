import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.utils import get_sim_time
import random

@cocotb.test()
async def test_minimal_phone(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        (3, 4, [3,2,1,0,0,0,0,0], [1,2,1,0,0,0,0,0], 2),
        (2, 3, [1,2,0,0,0,0,0,0], [23,17,0,0,0,0,0,0], 23),
        (3, 9, [7,8,3,0,0,0,0,0], [2,3,4,0,0,0,0,0], 5)
    ]

    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    total = len(test_cases)

    for test_id, (N_val, M_val, P_vals, C_vals, expected) in enumerate(test_cases):
        # Load test case
        dut.N.value = N_val
        dut.M.value = M_val
        dut.P0.value = P_vals[0]
        dut.C0.value = C_vals[0]
        dut.P1.value = P_vals[1]
        dut.C1.value = C_vals[1]
        dut.P2.value = P_vals[2]
        dut.C2.value = C_vals[2]
        dut.P3.value = P_vals[3]
        dut.C3.value = C_vals[3]
        dut.P4.value = P_vals[4]
        dut.C4.value = C_vals[4]
        dut.P5.value = P_vals[5]
        dut.C5.value = C_vals[5]
        dut.P6.value = P_vals[6]
        dut.C6.value = C_vals[6]
        dut.P7.value = P_vals[7]
        dut.C7.value = C_vals[7]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done signal
        for _ in range(150):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        result = dut.result.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"Test {test_id} passed: {result} == {expected}")
        else:
            dut._log.error(f"Test {test_id} failed: Got {result}, expected {expected}")

        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{total} tests passed")