import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_mentor(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (original samples scaled to HDL constraints)
    test_cases = [
        {
            "n": 4,
            "current": [2,1,4,3],
            "expected": [2,3,4,1]
        },
        {
            "n": 3,
            "current": [3,3,1],
            "expected": [3,1,2]
        },
        {
            "n": 2,
            "current": [2,1],
            "expected": [2,1]
        }
    ]

    passed = 0
    for tc in test_cases:
        # Apply reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.n.value = tc["n"]
        for i in range(8):
            if i < tc["n"]:
                dut.current_mentors[i].value = tc["current"][i] - 1  # 0-based indexing
            else:
                dut.current_mentors[i].value = 0
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check results
        valid = True
        for i in range(tc["n"]):
            actual = dut.new_mentors[i].value.integer + 1  # convert back to 1-based
            expected = tc["expected"][i]
            if actual != expected:
                dut._log.error(f"Mismatch at Gaggler {i+1}: got {actual}, expected {expected}")
                valid = False
        
        if valid:
            passed += 1
            dut._log.info(f"Test passed for n={tc["n"]}")
        else:
            dut._log.error(f"Test failed for n={tc["n"]}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
