import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import itertools
import random

@cocotb.test()
async def test_onion_protect(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test case 1: Original sample scaled down
    test1 = {
        "num_onions": 3, "num_posts": 5, "select_count": 3,
        "onion_x": [1,  2,  1],
        "onion_y": [1,  2,  3],
        "post_x": [0, 0, 1, 3, 3],
        "post_y": [0, 3, 4, 3, 0],
        "expected": 2
    }

    test2 = {
        "num_onions": 2, "num_posts": 4, "select_count": 3,
        "onion_x": [4,5],
        "onion_y": [4,5],
        "post_x": [0,0,6,6],
        "post_y": [0,6,6,0],
        "expected": 2
    }

    test_cases = [test1, test2]
    passed = 0

    # Common reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for case in test_cases:
        # Load inputs
        dut.num_onions.value = case["num_onions"]
        dut.num_posts.value = case["num_posts"]
        dut.select_count.value = case["select_count"]
        for i in range(8):
            dut.onion_x[i].value = case["onion_x"][i] if i < len(case["onion_x"]) else 0
            dut.onion_y[i].value = case["onion_y"][i] if i < len(case["onion_y"]) else 0
            dut.post_x[i].value = case["post_x"][i] if i < len(case["post_x"]) else 0
            dut.post_y[i].value = case["post_y"][i] if i < len(case["post_y"]) else 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check result
        if dut.max_protected.value == case["expected"]:
            passed += 1
        else:
            dut._log.error(f"Test failed: Got {dut.max_protected.value}, Expected {case["expected"]}")
        await Timer(20, units="ns")

    dut._log.info(f"Test summary: {passed}/{len(test_cases)} tests passed")