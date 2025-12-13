import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_sum_two_digit(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Define test cases (input_arr, k, expected_sum)
    test_cases = [
        ([1, -2, -3, 41, 0,0,0,0,0,0,0,0,0,0,0,0], 3, -5),
        ([111, 121, 3, 4000, 5,6,0,0,0,0,0,0,0,0,0,0], 2, 0),
        ([11, 21, 3, 90, 0,0,0,0,0,0,0,0,0,0,0,0], 4, 125),
        ([111, 21, 3, 4000, 0,0,0,0,0,0,0,0,0,0,0,0], 4, 24),
        ([1, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], 1, 1),
        ([99, -10, 100, 9, 0,0,0,0,0,0,0,0,0,0,0,0], 4, 89)
    ]
    
    passed = 0
    for arr, k, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        for i in range(16):
            dut.arr[i].value = arr[i] if i < len(arr) else 0
        dut.k.value = k
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        actual = dut.sum.value.signed_integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: k={k} sum={actual} (expected {expected})")
        else:
            dut._log.error(f"FAIL: k={k} got {actual}, expected {expected}")
        
        # Wait a cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")