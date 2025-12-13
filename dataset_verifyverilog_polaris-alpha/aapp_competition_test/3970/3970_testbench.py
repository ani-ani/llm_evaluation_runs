import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_k_multiple_free(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (adapted from original)
    test_cases = [
        # Original case 1 (n=6->8, keep same numbers)
        {"n":6, "k":2, "elements":[2,3,6,5,4,10,0,0,0,0,0,0,0,0,0,0], "expected":3},
        # Case 2 (n=2, special case)
        {"n":2, "k":2, "elements":[4,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0], "expected":1},
        # New case: simple ascending
        {"n":5, "k":2, "elements":[10,8,6,4,2,0,0,0,0,0,0,0,0,0,0,0], "expected":3},
        # New case: unique values
        {"n":3, "k":3, "elements":[5,7,9,0,0,0,0,0,0,0,0,0,0,0,0,0], "expected":3}
    ]

    passed = 0
    for test in test_cases:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.n.value = test["n"]
        dut.k.value = test["k"]
        for i in range(16):
            dut.elements[i].value = test["elements"][i] if i < test["n"] else 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check result
        if dut.result.value == test["expected"]:
            passed += 1
            dut._log.info(f"Test passed: {test['expected']}")
        else:
            dut._log.error(f"Test failed: Expected {test['expected']}, got {dut.result.value}")

    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")