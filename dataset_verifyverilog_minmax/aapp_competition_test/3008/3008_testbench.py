import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def ranker_test(dut):
    # Test cases (scaled to 8 assistants)
    test_inputs = [
        (10, [1,12]+[0]*6, [1,13]+[0]*6, 2),  # Original case 1
        (10, [1,5]+[0]*6, [1,12]+[0]*6, 2),   # Original case 2
        (10, [1,5]+[0]*6, [1,4]+[0]*6, 2),    # Original case 3
        (10, [1,5]+[0]*6, [4,1]+[0]*6, 2),    # Original case 4
        (10, [1,12]+[0]*6, [13,1]+[0]*6, 1)   # Additional case 5
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for (K_val, a_vals, b_vals, expected) in test_inputs:
        dut.K.value = K_val
        for i in range(8):
            dut.a_array[i].value = a_vals[i]
            dut.b_array[i].value = b_vals[i]
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        actual = dut.max_ranks.value.integer
        if actual == expected:
            passed += 1
        else:
            dut._log.error("Test failed: expected %d, got %d" % (expected, actual))
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_inputs)))