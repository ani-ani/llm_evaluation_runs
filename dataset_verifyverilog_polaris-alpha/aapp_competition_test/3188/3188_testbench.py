import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import numpy as np

@cocotb.test()
async def test_mst(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Scaled test cases (4 planets max)
    test_cases = [
        ([[1,0,0,0], [5,0,0,0], [0,0,0,0], [0,0,0,0]], 
         [[10,0,0,0], [8,0,0,0], [0,0,0,0], [0,0,0,0]], 
         [[2,0,0,0], [2,0,0,0], [0,0,0,0], [0,0,0,0]], 3),
        ([[-1,5,10,0], [0,0,0,0], [0,0,0,0], [0,0,0,0]], 
         [[-1,5,10,0], [0,0,0,0], [0,0,0,0], [0,0,0,0]], 
         [[-1,5,10,0], [0,0,0,0], [0,0,0,0], [0,0,0,0]], 6)
    ]
    
    passed = 0
    for (x_vals, y_vals, z_vals, expected) in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        for i in range(4):
            dut.x[i].value = int(x_vals[i])
            dut.y[i].value = int(y_vals[i])
            dut.z[i].value = int(z_vals[i])
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        for _ in range(52):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        if dut.total_cost.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: Got {dut.total_cost.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")