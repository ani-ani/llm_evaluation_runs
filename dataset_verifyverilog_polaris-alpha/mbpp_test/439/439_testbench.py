import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_concat(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ([[11], [33], [50], [0]], 113350),     # Original Test 1 adapted
        ([[-1], [2], [3], [4]], -1234),        # Original Test 2 adapted
        ([[10], [15], [20], [25]], 10152025),  # Original Test 3
        ([[127], [0], [0], [0]], 127000),      # Max positive case
        ([[-128], [1], [2], [3]], -128123)     # Min negative case
    ]
    
    passed = 0
    for inputs, expected in test_cases:
        # Pad input array to 4 elements
        padded = [0]*4
        for i, val in enumerate(inputs):
            padded[i] = val[0]
        
        # Apply inputs
        for i in range(4):
            dut.nums[i].value = padded[i]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        result_val = dut.result.value.signed_integer
        if result_val == expected:
            passed += 1
            dut._log.info(f"PASS: {inputs} => {result_val}")
        else:
            dut._log.error(f"FAIL: {inputs} => {result_val}, expected {expected}")
        
        # Wait a cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")