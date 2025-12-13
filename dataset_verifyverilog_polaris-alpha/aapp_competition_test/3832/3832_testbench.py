import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import numpy as np

@cocotb.test()
async def test_hill_houses(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Test cases (original scaled to n=8)
    test_cases = [
        # Input 1: 5 hills of 1
        ([1,1,1,1,1,0,0,0], [1, 2, 2]),
        # Input 2: 3 hills
        ([1,2,3,0,0,0,0,0], [0, 2]),
        # Input 3: 5 hills
        ([1,2,3,2,2,0,0,0], [0, 1, 3]),
        # Edge case: single hill
        ([10,0,0,0,0,0,0,0], [0]),
        # All flats
        ([2,2,2,2,2,2,2,2], [1,2,3,4])
    ]
    
    passed = 0
    for hills_data, expected in test_cases:
        # Zero out hills array
        for i in range(8):
            dut.hills[i].value = 0
        
        # Load hills data
        n = 0
        for i, val in enumerate(hills_data):
            dut.hills[i].value = val
            if val > 0: n = i+1
        
        num_expected = (n + 1)//2
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            dut._log.error("Timeout waiting for done")
        
        # Check results
        valid = True
        for k in range(num_expected):
            actual = dut.results[k].value.integer
            if actual != expected[k] and k < len(expected):
                dut._log.error(f"k={k+1} failed: Got {actual}, expected {expected[k]}")
                valid = False
        
        if valid:
            passed += 1
        
        # Wait a cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
