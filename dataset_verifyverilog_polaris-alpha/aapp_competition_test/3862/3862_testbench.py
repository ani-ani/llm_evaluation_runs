import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_min_coke(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (adapted to k<=16 and 1000 max conc)
    test_cases = [
        {
            "target_n": 400,
            "k": 4,
            "concentrations": [100, 300, 450, 500],
            "expected": 2
        },
        {
            "target_n": 50,
            "k": 2,
            "concentrations": [100, 25],
            "expected": 3
        },
        {
            "target_n": 326,
            "k": 4,
            "concentrations": [684, 49, 373, 575],
            "expected": 3
        },
        {
            "target_n": 0,
            "k": 1,
            "concentrations": [0],
            "expected": 1
        },
        {
            "target_n": 500,
            "k": 3,
            "concentrations": [499, 1000, 300],
            "expected": 7
        }
    ]

    passed = 0
    dut._log.info("Starting tests...")

    for tc in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.target_n.value = tc["target_n"]
        dut.k.value = tc["k"]
        for i in range(16):
            if i < len(tc["concentrations"]):
                dut.concentrations[i].value = tc["concentrations"][i]
            else:
                dut.concentrations[i].value = 0
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
            
        # Check result
        result = dut.min_liters.value
        if result == 0b1111111: result = -1  # Handle -1 encoding
        if result == tc["expected"]:
            passed += 1
            dut._log.info(f"PASS: Target={tc['target_n']} Got {int(result)}")
        else:
            dut._log.error(f"FAIL: Target={tc['target_n']} Expected {tc['expected']}, Got {int(result)}")
        await RisingEdge(dut.clk)

    dut._log.info(f"
SUMMARY: {passed}/{len(test_cases)} tests passed")
