import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        # Test case 1
        {
            "num": 3,
            "points": [(1,1), (1,2), (1,3)],
            "expected": 3
        },
        # Test case 2
        {
            "num": 3,
            "points": [(1,1), (2,1), (3,1)],
            "expected": 6
        },
        # Test case 3
        {
            "num": 4,
            "points": [(2,1), (2,2), (3,1), (3,2)],
            "expected": 6
        }
    ]

    passed = 0
    for test in test_cases:
        # Initialize inputs
        for i in range(8):
            if i < test["num"]:
                dut.point_x[i].value = test["points"][i][0]
                dut.point_y[i].value = test["points"][i][1]
            else:
                dut.point_x[i].value = 0
                dut.point_y[i].value = 0
        dut.num_points.value = test["num"]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        for _ in range(250):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            assert False, "Timeout waiting for done"

        # Check result
        if dut.count.value == test["expected"]:
            passed += 1
        else:
            dut._log.error(f"Test failed: Got {dut.count.value}, expected {test['expected']}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
