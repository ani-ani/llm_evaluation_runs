import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_kth_element(dut):
    # Generate clock (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    await Timer(20, units="ns")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (flattened arrays)
    test_cases = [
        # (arr, k, expected)
        ([12,3,5,7,19,0,0,0], 2, 3),   # Original Test1 + padding
        ([17,24,8,23,0,0,0,0], 3, 8),   # Original Test2
        ([16,21,25,36,4,0,0,0], 4, 36), # Original Test3
        ([255,128,64,32,16,8,4,2], 1, 2), # Edge case min k
        ([100,99,98,97,96,95,94,93], 8, 100) # Reverse-sorted array
    ]

    passed = 0
    for i, (arr, k_val, expected) in enumerate(test_cases):
        # Load inputs
        dut.start.value = 0
        dut.k.value = k_val
        for idx in range(8):
            dut.arr[idx].value = arr[idx]

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 32 cycles)
        for _ in range(40):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break

        # Verify result
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"Test {i+1} PASS: k={k_val}, result={dut.result.value}")
        else:
            dut._log.error(f"Test {i+1} FAIL: Expected {expected}, Got {dut.result.value}")

        # Insert 2 cycles gap between tests
        for _ in range(2):
            await RisingEdge(dut.clk)

    dut._log.info(f"
SUMMARY: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)