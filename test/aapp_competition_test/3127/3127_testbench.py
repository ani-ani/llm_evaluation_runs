import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_switch_analyzer(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1 (Sample Input 1 scaled to 8 nodes)
    test_data = [
        # Input 1: n=7, m=8
        (7, 8, [
            [1,2,0], [1,3,0], [1,4,0], [2,6,0], [2,7,0], [3,5,0], [4,7,0], [5,7,0],
            [0,0,0], [0,0,0], [0,0,0], [0,0,0], [0,0,0], [0,0,0], [0,0,0], [0,0,0]
        ], [
            2, 1, 3, 1, 2, 1, 2, 1, 0,0,0,0,0,0,0,0
        ], 0b01010000),  # Expected unused: 4 & 6 (bits 3 & 5 set)
        # Test case 2
        (5, 6, [
            [1,2,0], [2,3,0], [3,5,0], [1,4,0], [4,5,0], [1,5,0],
            [0,0,0], [0,0,0], [0,0,0], [0,0,0], [0,0,0], [0,0,0],
            [0,0,0], [0,0,0], [0,0,0], [0,0,0]
        ], [
            2,2,2,3,3,6,0,0,0,0,0,0,0,0,0,0
        ], 0b00000000),  # Expected none unused
    ]

    passed = 0
    for i, (n, m, edges, len_low, expected) in enumerate(test_data):
        # Load input data
        dut.n.value = n
        dut.m.value = m
        for idx in range(16):
            a,b,high = edges[idx]
            dut.edges[idx][0].value = a-1  # 0-based index
            dut.edges[idx][1].value = b-1
            dut.edges[idx][2].value = high
            dut.len_low[idx].value = len_low[idx]
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait 256 cycles max
        await ClockCycles(dut.clk, 256)
        # Check results
        if dut.done.value:
            result = dut.unused_mask.value
            if result == expected:
                passed += 1
            else:
                dut._log.error(f"Test {i+1} failed: Got {bin(result)}, expected {bin(expected)}")
        else:
            dut._log.error(f"Test {i+1} failed: Timeout without done signal")
    dut._log.info(f"Passed {passed}/{len(test_data)} tests")
