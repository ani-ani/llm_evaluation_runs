import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_consecutive(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Test cases (pad to 8 elements with zeros)
    test_cases = [
        ([1,2,3,4,5,0,0,0], True),
        ([1,2,3,5,6,0,0,0], False),
        ([1,2,1,0,0,0,0,0], False),
        ([5,6,7,8,9,10,11,12], True),
        ([-3,-2,-1,0,1,2,3,4], True),
        ([1,3,5,7,9,11,13,15], False)
    ]

    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for data, expected in test_cases:
        # Apply test vector
        for i in range(8):
            dut.array_in[i].value = data[i]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Verify result
        if dut.consecutive.value == expected:
            passed += 1
            dut._log.info(f"PASS: {data[:5]}... -> {expected}")
        else:
            dut._log.error(f"FAIL: {data[:5]}... -> {dut.consecutive.value}, expected {expected}")
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)