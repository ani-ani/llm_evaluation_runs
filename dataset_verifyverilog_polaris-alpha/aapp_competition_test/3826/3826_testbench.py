import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_min_subsegment(dut):
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
        (3, [1,2,3], 0),   # Original Test 1
        (4, [1,1,2,2], 2), # Original Test 2
        (5, [1,4,1,4,9], 2), # Original Test 3
        (2, [2,1], 0),     # Modified Test 1
        (8, [1,2,3,4,1,5,6,4], 2) # Modified Test from TC19
    ]
    
    passed = 0
    for n_val, arr, expected in test_cases:
        # Load inputs
        dut.n.value = n_val
        for i in range(8):
            dut.a[i].value = arr[i] if i < len(arr) else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.min_size.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: n={n_val} arr={arr} got {dut.min_size.value}, expected {expected}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")