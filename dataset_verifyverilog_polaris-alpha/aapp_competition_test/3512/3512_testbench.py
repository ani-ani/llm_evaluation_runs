import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_tsp(dut):
    # Create clock generator
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Define test cases (n, flat_matrix, expected)
    test_cases = [
        (3, 
         [0,5,2,5,0,4,2,4,0] + [0]*55, 
         7),
        (4,
         [0,15,7,8,15,0,16,9,7,16,0,12,8,9,12,0] + [0]*48,
         31)
    ]
    
    passed = 0
    
    for test_id, (n_val, matrix, expected) in enumerate(test_cases):
        # Reset module
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.n.value = n_val 
        for i in range(64):
            dut.dist_matrix[i].value = matrix[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 64 cycles)
        cycle_count = 0
        while not dut.done.value and cycle_count < 100:
            await RisingEdge(dut.clk)
            cycle_count += 1
        
        if cycle_count >= 100:
            dut._log.error(f"Test {test_id} timed out")
        else:
            result = dut.min_duration.value.integer
            if result == expected:
                passed += 1
                dut._log.info(f"Test {test_id} passed: {result}")
            else:
                dut._log.error(f"Test {test_id} failed: got {result}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, "Some tests failed"