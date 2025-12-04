import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_min_papers(dut):
    # Convert decimal P to Q12.10 fixed-point (multiply by 1024)
    test_cases = [
        (5.0, [0, 0, 0, 0, 1]), # 5.0 * 1024 = 5120
        (4.5, [0, 0, 0, 1, 1]), # 4.5 * 1024 = 4608
        (3.20, [2, 0, 0, 1, 2]) # 3.20 * 1024 = 3276.8 ≈ 3277
    ]
    
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for P_val, expected in test_cases:
        # Convert to fixed-point
        P_fixed = int(P_val * 1024 + 0.5)
        dut.P_fixed.value = P_fixed
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 2000 cycles)
        timeout = 2000
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        assert timeout > 0, "Timeout waiting for solution"
        
        # Check outputs
        counts = [int(dut.ones.value), int(dut.twos.value), int(dut.threes.value),
                 int(dut.fours.value), int(dut.fives.value)]
        
        if counts == expected:
            passed += 1
        else:
            dut._log.error(f"Failed for P={P_val}: Got {counts}, expected {expected}")
        
        await RisingEdge(dut.clk)
        dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), f"{passed}/{len(test_cases)} tests passed"