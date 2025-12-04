import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_rearrange(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (pad to 16 elements with zeros)
    test_cases = [
        (9, [-1, 2, -3, 4, 5, 6, -7, 8, 9] + [0]*7, [-1, -3, -7, 2, 4, 5, 6, 8, 9] + [0]*7),
        (5, [12, -14, -26, 13, 15] + [0]*11, [-14, -26, 12, 13, 15] + [0]*11),
        (7, [10, 24, 36, -42, -39, -78, 85] + [0]*9, [-42, -39, -78, 10, 24, 36, 85] + [0]*9),
        (16, [127, -128, 0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5, -6, 6, -7],
              [-128, -1, -2, -3, -4, -5, -6, -7, 127, 0, 1, 2, 3, 4, 5, 6])  # Edge case
    ]
    
    passed = 0
    for test_num, (n_val, arr_in, expected) in enumerate(test_cases):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Apply inputs
        dut.n.value = n_val
        for i in range(16):
            dut.arr_in[i].value = arr_in[i]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing
        for _ in range(16):
            await RisingEdge(dut.clk)
        
        # Check output
        result = [dut.arr_out[i].value.signed_integer for i in range(16)]
        if result == expected:
            passed += 1
            dut._log.info(f"Test {test_num} PASSED")
        else:
            error_msg = f"Test {test_num} FAILED: Got {result}, Expected {expected}"
            dut._log.error(error_msg)
            
        await RisingEdge(dut.clk)
        
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)