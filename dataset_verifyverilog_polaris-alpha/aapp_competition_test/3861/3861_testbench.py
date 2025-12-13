import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import math

@cocotb.test()
async def test_max_non_square(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    test_cases = [
        ([4, 2, 0, 0, 0, 0, 0, 0], 2), 
        ([1, 2, 4, 8, 16, 32, 64, 576], 32),
        ([-1, -4, -9, 0, 0, 0, 0, 0], -1),~~~~
        ([15, 131073, 0, 0, 0, 0, 0, 0], 131073), 
        ([-1000000, 1000000, 0, 0, 0, 0, 0, 0], -1000000), 
        ([999999, 3, 0, 0, 0, 0, 0, 0], 999999)
    ]
    
    passed = 0
    
    for arr, expected in test_cases:
        # Initialize and reset
        dut.rst_n.value = 0
        dut.start.value = 0
        for i in range(8):
            dut.arr[i].value = arr[i] if i < len(arr) else 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing cycles
        for _ in range(9):
            await RisingEdge(dut.clk)
        
        # Check results
        if dut.done.value == 1 and dut.result.value.signed_integer == expected:
            passed += 1
        else:
            dut._log.error("Test failed: Expected %d, Got %d" % (expected, dut.result.value.signed_integer))
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))