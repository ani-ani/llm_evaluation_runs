import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_damage(dut):
    # Create 50MHz clock
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled original + edge cases)
    test_cases = [
        # Original Sample 1 (scaled)
        {"jiro": [(1, 2000), (0, 1700)], "ciel": [2500,2500,2500], "expected": 3000},
        # Original Sample 2 (ones' digit only)
        {"jiro": [(1,10), (1,100), (1,1000)], "ciel": [1,11,101,1001], "expected": 992},
        # Defense only test
        {"jiro": [(0, 500), (0, 1000)], "ciel": [600, 700], "expected": 0},
        # Immediate damage when no Jiro cards
        {"jiro": [], "ciel": [100, 200], "expected": 300},
        # Max values test
        {"jiro": [(1, 65535)], "ciel": [65535], "expected": 0}
    ]

    passed = 0
    dut._log.info(f"Starting {len(test_cases)} tests")

    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        jiro = case["jiro"]
        ciel = case["ciel"]
        dut.jiro_cnt.value = len(jiro)
        dut.ciel_cnt.value = len(ciel)

        for i in range(4):
            if i < len(jiro):
                dut.j_type[i].value = jiro[i][0]
                dut.j_strength[i].value = jiro[i][1]
            else:
                dut.j_type[i].value = 0
                dut.j_strength[i].value = 0

            if i < len(ciel):
                dut.c_strength[i].value = ciel[i]
            else:
                dut.c_strength[i].value = 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 25 cycles)
        timeout = 0
        while (dut.done.value != 1 and timeout < 25):
            await RisingEdge(dut.clk)
            timeout += 1

        assert timeout < 25, "Timed out waiting for done"
        result = dut.damage.value.integer

        if result == case["expected"]:
            passed += 1
        else:
            dut._log.error(f"Test failed. Expected {case['expected']}, got {result}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)
