import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_frequency_max(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (adapted for 8 elements)
    test_cases = [
        ([5,5,5,5,1,0,0,0], 1),   # [5,5,5,5,1] → 1
        ([4,1,4,1,4,4,0,0], 4),   # [4,1,4,1,4,4] → 4
        ([3,3,0,0,0,0,0,0], -1),  # [3,3] → -1
        ([8,8,8,8,8,8,8,8], 8),   # Original test
        ([2,3,3,2,2,0,0,0], 2),   # [2,3,3,2,2] → 2
        ([1,0,0,0,0,0,0,0], 1),   # Singleton case
        ([10,10,10,10,0,0,0,0], -1) # [10*4] → -1 (need 10 occurrences)
    ]
    
    passed = 0
    for data, expected in test_cases:
        # Load inputs
        for i in range(8):
            dut.data[i].value = data[i]
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        result = dut.result.value.signed_integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {data} → {result}")
        else:
            dut._log.error(f"FAIL: {data} → {result}, expected {expected}")
        
        # Small delay between tests
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")