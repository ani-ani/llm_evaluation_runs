import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_taboo(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        # Test case 1 (scaled-down sample)
        {"n": 2'd3, "t0":4'b0011, "t1":4'b0010, "t2":4'b0000, "t3":4'b0001, "found":1, "result":0b1000},
        # Test case 2 (single taboo)
        {"n":2'd1, "t0":4'b0011, "t1":0, "t2":0, "t3":0, "found":1, "result":0b11111111},
        # Test case 3 (full taboos)
        {"n":2'd3, "t0":4'b0000, "t1":4'b0001, "t2":4'b0010, "t3":4'b0011, "found":1, "result":0b11}
    ]
    passed = 0
    dut.start.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
    for case in test_cases:
        dut.n_taboos.value = case["n"]
        dut.taboo0.value = case["t0"]
        dut.taboo1.value = case["t1"]
        dut.taboo2.value = case["t2"]
        dut.taboo3.value = case["t3"]
        dut.start.value = 1
        await ClockCycles(dut.clk, 1)
        dut.start.value = 0
        await ClockCycles(dut.clk, 40)  # Allow max computation time
        if dut.done.value == 1:
            valid = (dut.found.value == case["found"])
            if dut.found.value:
                valid &= (dut.result.value == case["result"])
            if valid:
                passed += 1
            else:
                dut._log.error("Test failed: Got found=%d result=%d, expected found=%d result=%d" % 
                             (dut.found.value, dut.result.value, case["found"], case["result"]))
        else:
            dut._log.error("Test failed: Did not complete within 40 cycles")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)