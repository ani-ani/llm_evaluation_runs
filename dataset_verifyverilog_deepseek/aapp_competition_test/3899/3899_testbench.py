import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_threshold(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Adapted test cases (original scaled to 4 tasks)
    test_cases = [
        # Original Example 1 (subset)
        {"power": [10,9,9,8], "procs": [1,1,1,1], "expected": 9000},
        # Original Example 2 (subset)
        {"power": [10,9,10,8], "procs": [10,5,10,1], "expected": 1160},
        # Single-task case"
        {"power": [100000000], "procs": [1], "expected": 100000000000}
    ]
    passed = 0
    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        # Load inputs (pad with 0s for smaller test cases)
        for i in range(4):
            dut.power[i].value = case["power"][i] if i \u003c len(case["power"]) else 0
            dut.processors[i].value = case["procs"][i] if i \u003c len(case["procs"]) else 0
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion
        for _ in range(60):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        # Check result
        actual = dut.result.value.integer
        expected = case["expected"]
        if actual == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed:
Input: {case["power"]} | {case["procs"]}
Got {actual}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
