import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_dora(dut):
    # Reduced test cases (original scaled to 4x4 where needed)
    test_cases = [
        # Input 2x3 adapted to 4x4
        {'grid': [[1,2,1,0], [2,1,2,0], [0,0,0,0], [0,0,0,0]],
         'targets': [(0,0,2), (0,1,2), (0,2,2), (1,0,2), (1,1,2), (1,2,2)]},
        # Input 2x2 adapted
        {'grid': [[1,2,0,0], [3,4,0,0], [0,0,0,0], [0,0,0,0]],
         'targets': [(0,0,2), (0,1,3), (1,0,3), (1,1,2)]}
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    passed = 0
    total = 0
    
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    
    for case in test_cases:
        # Load grid values (not implemented in this simplified test)
        # In full implementation would write to memory interface
        
        for (i,j,expected) in case['targets']:
            total += 1
            dut.target_i.value = i
            dut.target_j.value = j
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for computation (6 cycles)
            await ClockCycles(dut.clk, 6)
            
            if dut.x_result.value == expected:
                passed += 1
            else:
                dut._log.error(f"Failed at ({i},{j}): Got {dut.x_result.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, "Some tests failed"