import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

MOD = 1000000009

@cocotb.test()
async def test_evenland(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Precomputed powers of 2 mod 10^9 +9 for 0-15
    pow_lut = [pow(2,i,MOD) for i in range(16)]
    
    test_cases = [
        #{n=4, m=5, expected=4}
        {'n':4, 'm':5, 'edges':[
            (1,2), (1,3), (1,4), (2,3), (2,4), # edge list
            (0,0),(0,0),(0,0),(0,0),(0,0), # padding for 15 edges
            (0,0),(0,0),(0,0),(0,0),(0,0)]}, 
        #{n=2, m=1, expected=1}
        {'n':2, 'm':1, 'edges':[(1,2)] + [(0,0)]*14},
        #{n=3, m=3, edges form triangle, expected=1
        {'n':3, 'm':3, 'edges':[(1,2),(2,3),(3,1)] + [(0,0)]*12},
        #{n=1, m=0 -> rank=0, 2^0=1
        {'n':1, 'm':0, 'edges':[(0,0)]*15}
    ]
    expected = [4,1,1,1]
    
    
    passed = 0
    for i, (test, exp) in enumerate(zip(test_cases, expected)):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Pack edges
        edge_bits = 0
        for j, (a,b) in enumerate(test['edges']):
            edge_bits |= (a & 0x7) << (6*j + 3)
            edge_bits |= (b & 0x7) << (6*j)
        
        # Apply inputs
        dut.n.value = test['n']
        dut.m.value = test['m']
        dut.edges.value = edge_bits
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 16 cycles)
        timeout = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            timeout +=1
            if timeout > 30:
                assert False, "Timeout waiting for done"
        
        # Check result
        if dut.way.value == exp:
            passed +=1
        else:
            dut._log.error(f"Test {i} failed: Got {int(dut.way.value)}, expected {exp}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)