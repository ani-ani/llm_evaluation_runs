import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_loot_divider(dut):
    # Generate clock (100MHz)
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    # Initialize test cases (k, x_array, expected)
    test_cases = [  
        (4, [0, 2, 0, 1, 0,0,0,0], 8),
        (5, [255,1,1,1,1,0,0,0], 0),
        (5, [3,3,3,3,3,0,0,0], 1),
        (3, [1,0,0,0,0,0,0,0], 1),
        (2, [0,3,0,0,0,0,0,0], 2)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for (k_val, x_vals, expected) in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        for i in range(8):
            dut.x[i].value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Apply inputs
        dut.k.value = k_val
        for i in range(8):
            dut.x[i].value = x_vals[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        actual = dut.left_behind.value.integer
        if actual != expected:
            dut._log.error(f"Test failed: k={k_val} x={x_vals}\
              Expected {expected}, got {actual}")
        else:
            passed += 1
        
        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Result summary
    dut._log.info(f"{passed}/{total} tests passed")
