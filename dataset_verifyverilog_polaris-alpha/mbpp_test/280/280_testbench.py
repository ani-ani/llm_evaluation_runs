import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_sequential_search(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Reset system
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(15, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (array, item, expect_found, expect_index)
    test_cases = [
        ([11,23,58,31,56,77,43,12], 31, 1, 3),
        ([12,32,45,62,35,47,44,61], 61, 1, 7),
        ([9,10,17,19,22,39,48,56], 48, 1, 6),
        ([11,23,58,31,56,77,43,12], 100, 0, 0b1111),
        ([255,0,128,64,32,16,8,4], 255, 1, 0)
    ]

    passed = 0
    for arr, item, exp_found, exp_index in test_cases:
        # Load array
        for i in range(8):
            dut.array[i].value = arr[i]
        dut.item.value = item

        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check results
        if (dut.found.value == exp_found) and (dut.index.value == exp_index):
            passed += 1
            dut._log.info(f"PASS: {item} in {arr} => found={exp_found}, idx={exp_index}")
        else:
            dut._log.error(f"FAIL: {item} in {arr} => got found={dut.found.value}, idx={dut.index.value} (expected {exp_found}, {exp_index})")

        # Reset for next test
        dut.rst_n.value = 0
        await Timer(10, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")