import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def conveyor_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        # Test 1: Sample Input 1 (scaled values)
        {
            "N": 4, "K": 2, "M": 3,
            "edges": [1<<3|3, 2<<3|3, 3<<3|4], "expected": 2
        },
        # Test 2: Sample Input 2 (scaled values)
        {
            "N":5, "K":2, "M":4,
            "edges":[1<<3|3, 3<<3|4, 2<<3|4,4<<3|5], "expected":1
        },
        # Test 3: Additional test case
        {
            "N":5, "K":2, "M":6,
            "edges":[1<<3|4, 2<<3|3, 3<<3|4,4<<3|5,2<<3|4,3<<3|3], "expected":2
        }
    ]
    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for test in test_cases:
        # Load inputs
        dut.N.value = test["N"]
        dut.K.value = test["K"]
        dut.M.value = test["M"]
        for i in range(16):
            dut.edges.value[i] = test["edges"][i] if i < len(test["edges"]) else 0
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion (64 cycles)
        for _ in range(64):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        # Check result
        result = dut.max_producers.value.integer
        if result == test["expected"]:
            passed += 1
        else:
            dut._log.error(f"Failed: Expected {test['expected']}, got {result}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)