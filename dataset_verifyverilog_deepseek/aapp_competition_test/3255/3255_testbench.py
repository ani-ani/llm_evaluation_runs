import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_hopper(dut):
    # Generate clock (100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (adapted from samples)
    test_cases = [
        # Input: [array], D, M, expected_output
        ([1,7,8,2,6,4,3,5], 3, 1, 8),
        ([1,7,8,2,6,4,3,5], 2, 1, 3),
        ([1,7,8,2,6,4,3,5], 1, 1, 2),
        ([5,4,3,4,5], 3, 0, 1),  # Additional edge case (M=0)
        ([10,20,30,40,50,60,70,80], 7, 10, 8)  # Full range jump
    ]
    passed = 0
    total = len(test_cases)
    
    # Apply reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for arr, D, M, expected in test_cases:
        # Pad array to 8 elements
        padded_arr = arr + [0]*(8-len(arr)) if len(arr) < 8 else arr[:8]
        
        # Load inputs
        dut.start.value = 0
        dut.D.value = D
        dut.M.value = M if M >=0 else int(M + (1<<8))  # Handle signed
        for i in range(8):
            setattr(dut, f"arr_{i}", padded_arr[i])
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 64 cycles)
        timeout = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 100:
                assert False, "Timeout waiting for done"
        
        # Check result
        actual = dut.max_length.value.integer
        if actual == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: arr={padded_arr}, D={D}, M={M} -> {actual}, expected {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{total} tests passed")