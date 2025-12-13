import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.handle import Force
import numpy as np

@cocotb.test()
async def test_protest_location(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (n,x0,y0,x1,y1,...,d)
    test_cases = [
        (5, [3,4,5,2,5,0,0,0], [1,1,9,6,3,0,0,0], 10, 18, 0),  # Original Sample 1
        (5, [3,4,5,2,5,0,0,0], [1,1,9,6,3,0,0,0], 5, 20, 0),   # Original Sample 2
        (5, [3,4,5,2,5,0,0,0], [1,1,9,6,3,0,0,0], 4, 0, 1)    # Impossible case
    ]
    
    passed = 0
    for tc in test_cases:
        dut.n.value = tc[0]
        for i in range(8):
            dut.data_x[i].value = tc[1][i]
            dut.data_y[i].value = tc[2][i]
        dut.d.value = tc[3]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 20 cycles for computation
        for _ in range(20):
            await RisingEdge(dut.clk)
        
        if dut.impossible.value == tc[5]:
            if tc[5] or (dut.total_distance.value == tc[4]):
                passed += 1
        else:
            dut._log.error("Test failed: n=%d d=%d expected_total=%d expected_impossible=%s got_total=%d got_imp=%s" % 
                (tc[0], tc[3], tc[4], str(bool(tc[5])), dut.total_distance.value, str(bool(dut.impossible.value))))
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")