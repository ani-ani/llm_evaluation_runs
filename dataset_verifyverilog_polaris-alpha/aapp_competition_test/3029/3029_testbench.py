import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_tree_jumping_path(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    test_cases = [
        {
            "u": [3, 3, 3, 3],
            "p": [1, 2, 3],
            "L": 4,
            "M_mod": 1
        },
        {
            "u": [4, 3, 2, 1],
            "p": [1, 2, 3],
            "L": 1,
            "M_mod": 4
        },
        {
            "u": [1, 5, 3, 6],
            "p": [1, 2, 3],
            "L": 3,
            "M_mod": 2
        },
        {
            "u": [1, 2, 0, 3],
            "p": [1, 1, 1],
            "L": 2,
            "M_mod": 2
        }
    ]
    passed = 0
    for test in test_cases:
        dut.u_1.value = test["u"][0]
        dut.u_2.value = test["u"][1]
        dut.u_3.value = test["u"][2]
        dut.u_4.value = test["u"][3]
        dut.p_2.value = test["p"][0]
        dut.p_3.value = test["p"][1]
        dut.p_4.value = test["p"][2]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
        if dut.L.value == test["L"] and dut.M_mod.value == test["M_mod"]:
            passed += 1
        else:
            dut._log.error(f"Test failed: For u={test['u']}, p={test['p']} expected L={test['L']}, M_mod={test['M_mod']} but got L={dut.L.value}, M_mod={dut.M_mod.value}")
        await RisingEdge(dut.clk)
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")