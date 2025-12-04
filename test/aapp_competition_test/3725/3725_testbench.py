import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_frog_flower(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    # Test cases (m, h1,a1,x1,y1, h2,a2,x2,y2, expected_time)
    test_cases = [
        # Original 1st sample (m=5)
        (5, 4,2,1,1, 0,1,2,3, 3),
        # No solution case (m=2)
        (2, 0,1,0,1, 0,1,0,1, -1),
        # Custom solvable case (m=3)
        (3, 1,0,0,1, 1,2,1,0, 1)
    ]
    
    passed = 0
    for case in test_cases:
        m, h1,a1,x1,y1, h2,a2,x2,y2, expected = case
        
        # Apply reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.m.value = m
        dut.h1.value = h1
        dut.a1.value = a1
        dut.x1.value = x1
        dut.y1.value = y1
        dut.h2.value = h2
        dut.a2.value = a2
        dut.x2.value = x2
        dut.y2.value = y2
        dut.start.value = 1
        
        # Wait for completion (max 3100 cycles)
        timeout = 0
        while not dut.done.value and timeout < 3100:
            await RisingEdge(dut.clk)
            timeout += 1
        
        # Check results
        if timeout >= 3100:
            dut._log.error("Test timeout")
        else:
            if expected == -1:
                if dut.fail.value:
                    passed += 1
                else:
                    dut._log.error(f"Expected fail but got time={dut.time_out.value}")
            else:
                if dut.time_out.value == expected and not dut.fail.value:
                    passed += 1
                else:
                    dut._log.error(f"Expected time={expected} got {dut.time_out.value} fail={dut.fail.value}")
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
