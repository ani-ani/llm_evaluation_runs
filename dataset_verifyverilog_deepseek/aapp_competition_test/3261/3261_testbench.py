import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.triggers import FallingEdge
import numpy as np

@cocotb.test()
async def test_grey_counter(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (R, C, K, expected)
    test_cases = [
        (10, 10, 6, 5),
        (3, 5, 11, 8),
        (10, 10, 100, 51)
    ]
    
    passed = 0
    
    for (R_val, C_val, K_val, expected) in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.R.value = R_val
        dut.C.value = C_val
        dut.K.value = K_val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
        
        # Check output
        if dut.count.value == expected:
            passed += 1
        else:
            dut._log.error("Test failed: R=%d C=%d K=%d => Count=%d (expected %d)" % 
                            (R_val, C_val, K_val, dut.count.value, expected))
        
        # Wait a cycle after done
        await RisingEdge(dut.clk)
    
    dut._log.info("Test summary: %d/%d passed" % (passed, len(test_cases)))