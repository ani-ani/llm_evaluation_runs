import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_garbage_bags(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        (2, [3,2,1], 3, 3),  # n,k,data,expected
        (1, [1,0,1], 2, 2),  # Scaled from test 3
        (4, [2,8,4,1], 4, 4),  # Original test 4
        (1, [0], 1, 0),  # Zero garbage
        (1, [1], 1, 1)   # Single bag
    ]
    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(15, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    for (test_n, data, test_k, expected) in test_cases:
        # Load data
        for i in range(16):
            dut.days_data[i].value = data[i] if i < len(data) else 0
        dut.n.value = test_n if test_n < len(data) else len(data)
        dut.k.value = test_k
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0 
        # Wait for processing cycles
        for _ in range(test_n + 2):
            await RisingEdge(dut.clk)
        
        if dut.done.value != 1:
            await RisingEdge(dut.done)
        if dut.total_bags.value == expected:
            passed += 1
        else:
            dut._log.error("Test failed: Got %d, Expected %d" % 
                        (dut.total_bags.value, expected))
        
        # Reset between test cases
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
