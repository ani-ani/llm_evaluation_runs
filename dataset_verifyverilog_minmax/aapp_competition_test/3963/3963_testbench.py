import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

MOD_P = 1000000007

@cocotb.test()
async def test_coin_change(dut):
    # Generate clock (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize and reset
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases (adapted from original examples)
    test_cases = [
        (1, [], [4], 2, 1),  # Input 1
        (2, [1], [4,4], 2, 3),  # Input 2
        (3, [3,3], [10,10,10], 17, 6)  # Input 3
    ]
    
    passed = 0
    for n, a, b, m, expected in test_cases:
        # Configure inputs
        dut.num_coins.value = n
        for i in range(7):
            if i < len(a):
                dut.a[i].value = a[i]
            else:
                dut.a[i].value = 0
        for i in range(8):
            if i < len(b):
                dut.b[i].value = b[i]
            else:
                dut.b[i].value = 0
        dut.m.value = m
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (worst-case cycles = n*m)
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        actual = dut.result.value
        if actual.integer == expected % MOD_P:
            passed += 1
        else:
            dut._log.error("Test failed: n=%d m=%d Expected %d Got %d" % (n, m, expected, actual))
        await Timer(10, units="ns")  # Cleanup time
    
    # Summary
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))
    assert passed == len(test_cases)
