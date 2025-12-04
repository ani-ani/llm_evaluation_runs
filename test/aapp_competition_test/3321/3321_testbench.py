import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_frog_regent(dut):
    # Test cases (adapted with N=8 padding unused with zeros)
    test_cases = [
        { # Sample 1
            "init": [1,5,4,3,2,6,0,0],
            "target": [1,2,5,4,3,6,0,0],
            "expected": [2,0],  # Expected proclamations (0-padded)
            "len": 1
        },
        { # Sample 2
            "init": [1,5,3,2,4,0,0,0],
            "target": [1,5,4,2,3,0,0,0],
            "expected": [5,3,5,2,0],  # Expected: 5,3,5,2 
            "len": 4
        }
    ]

    clock = Clock(dut.clk, 10, units="ns")  # Create 10ns period clock
    cocotb.start_soon(clock.start())  # Start the clock

    total_passed = 0
    for test_idx, tc in enumerate(test_cases):
        # Reset and initialize
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load sequences
        for i in range(8):
            dut.init_seq[i].value = tc["init"][i]
            dut.target_seq[i].value = tc["target"][i]

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Collect outputs
        results = []
        for step in range(16):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
            if dut.proclamation.value != 0:
                results.append(int(dut.proclamation.value))
        # Pad results to compare
        results += [0]*(16 - len(results))

        # Check
        passed = (results[:tc["len"]] == tc["expected"][:tc["len"]])
        if passed:
            total_passed += 1
        else:
            dut._log.error(f"Test {test_idx} failed: Got {results[:tc['len']]} vs expected {tc['expected'][:tc['len']]}")

        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1

    dut._log.info(f"{total_passed}/{len(test_cases)} tests passed")
    assert total_passed == len(test_cases)