import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_shift_check(dut):
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
        # Original test cases adapted for 8-element max
        (5, [3, 4, 5, 1, 2], True),   # Original test case
        (5, [3, 5, 10, 1, 2], True),  # Valid rotation exists
        (4, [4, 3, 1, 2], False),     # Not sortable
        (5, [3, 5, 4, 1, 2], False),  # Original test case
        (0, [], True)                  # Empty array
    ]
    
    passed = 0
    for size, data, expected in test_cases:
        # Load test data (pad with zeros to 8 elements)
        padded_data = data + [0]*(8 - len(data))
        for i in range(8):
            dut.arr[i].value = padded_data[i]
        dut.arr_size.value = size
        
        # Trigger processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
            
        # Check result
        await RisingEdge(dut.clk)
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: {data} => {dut.result.value} (expected {expected})")
        else:
            dut._log.error(f"FAIL: {data} => {dut.result.value} (expected {expected})")
        
        # Reset for next case
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)