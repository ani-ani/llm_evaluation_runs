import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

@cocotb.test()
async def test_subset(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (padded to 8 elements)
    test_cases = [
        ([1,3,6,13,17,18,0,0], 6, 4),
        ([10,5,3,15,20,0,0,0], 5, 3),
        ([18,1,3,6,13,17,0,0], 6, 4),
        ([2,4,8,16,0,0,0,0], 4, 4),  # Additional test case
        ([7,0,0,0,0,0,0,0], 1, 1)    # Edge case
    ]

    passed = 0
    for numbers, size, expected in test_cases:
        # Load inputs
        dut.start.value = 0
        dut.size.value = size
        for i in range(8):
            dut.numbers[i].value = numbers[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 30 cycles)
        for _ in range(30):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        if dut.max_size.value == expected:
            passed += 1
            dut._log.info(f"PASS: {numbers[:size]} -> {dut.max_size.value}")
        else:
            dut._log.error(f"FAIL: {numbers[:size]} got {dut.max_size.value}, expected {expected}")
        
        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} passed")
