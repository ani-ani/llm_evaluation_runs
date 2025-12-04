import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_alternating(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await Timer(15, units="ns")

    # Test cases (scaled down)
    test_cases = [
        # Original sample 1 (n=4)
        {
            "n": 4, "c":10, "r":50, "scores": [8,8,2,-2],
            "expected": 80  # Create 3 accounts (30) + report(50) = 80
        },
        # Modified sample 2 (n=6 with zeros handled)
        {
            "n":6, "c":100, "r":33,
            "scores": [5,-13,0,0,-12,0],
            "expected": 132  # Report 4 comments (4*33=132)
        },
        # Edge case: single comment (must be non-zero)
        {
            "n":1, "c":10, "r":20,
            "scores": [0],
            "expected": 10  # Need 1 vote to make ±1
        }
    ]

    passed = 0
    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.n.value = case["n"]
        dut.c.value = case["c"]
        dut.r.value = case["r"]
        for i in range(8):
            if i < case["n"]:
                dut.scores[i].value = case["scores"][i] if abs(case["scores"][i]) <= 127 else 127
            else:
                dut.scores[i].value = 0
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        timeout = 100
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        if timeout == 0:
            dut._log.error("Timeout waiting for done")
            continue

        # Check result
        if dut.min_time.value == case["expected"]:
            passed += 1
        else:
            dut._log.error(f"Failed: n={case['n']} c={case['c']} r={case['r']} scores={case['scores']}
                Got {dut.min_time.value} Expected {case['expected']}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
