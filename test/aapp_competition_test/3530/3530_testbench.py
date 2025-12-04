import cocotb
from cocotb.triggers import RisingEdge, Timer, ClockCycles
from cocotb.clock import Clock
from math import floor

@cocotb.test()
async def test_fun_max(dut):
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1: Simple case (2 coasters)
    test_cases = [
        {
            "num": 2, 
            "a": [5, 7], 
            "b": [0, 0], 
            "t": [5,7], 
            "T": 88 
        },
        {
            "num": 2, 
            "a": [5, 7], 
            "b": [0, 0], 
            "t": [5,7], 
            "T": 5 
        }
    ]
    expected = [88, 5]
    passed = 0

    for i in range(len(test_cases)):
        # Load inputs
        dut.num_coasters.value = test_cases[i]["num"]
        dut.a1.value = test_cases[i]["a"][0]
        dut.a2.value = test_cases[i]["a"][1]
        dut.b1.value = test_cases[i]["b"][0]
        dut.b2.value = test_cases[i]["b"][1]
        dut.t1.value = test_cases[i]["t"][0]
        dut.t2.value = test_cases[i]["t"][1]
        dut.T.value = test_cases[i]["T"]

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done signal (max 64 cycles)
        done = False
        timeout = 0
        while not done and timeout < 80:
            await RisingEdge(dut.clk)
            done = dut.done.value
            timeout += 1

        if timeout >= 80:
            dut._log.error("Test case %d timed out" % i)
            continue

        result = dut.max_fun.value.integer
        if result == expected[i]:
            passed += 1
            dut._log.info("Test %d passed: Expected 0x%x, Got 0x%x" % (i, expected[i], result))
        else:
            dut._log.error("Test %d failed: Expected 0x%x, Got 0x%x" % (i, expected[i], result))

    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))