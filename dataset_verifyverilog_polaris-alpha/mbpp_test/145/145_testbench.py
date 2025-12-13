import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_diff(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Helper function
    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases (padded to 8 elements)
    test_cases = [
        ([2, 1, 5, 3, 0, 0, 0, 0], 4),   # Original: [2,1,5,3]
        ([9,3,2,5,1,0,0,0], 8),       # Original: [9,3,2,5,1]
        ([3,2,1,0,0,0,0,0], 2),       # Original: [3,2,1]
        ([127, -128, 0,0,0,0,0,0], 255), # Edge case
        ([10,10,10,10,10,10,10,10], 0),  # All same
        ([1,2,3,4,5,6,7,8], 7)        # Increasing sequence
    ]
    
    await reset()
    passed = 0
    
    for arr, expected in test_cases:
        # Load input array
        for i in range(8):
            dut.arr[i].value = arr[i] & 0xff  # Convert to 8-bit signed
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 8 cycles + 1 for output
        for _ in range(9):
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.done.value == 1 and dut.max_diff.value == expected:
            passed += 1
            dut._log.info(f"PASS: {arr} -> {dut.max_diff.value}")
        else:
            dut._log.error(f"FAIL: {arr} got {dut.max_diff.value}, expected {expected}")
        
        # Wait 1 more cycle to clear done
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")