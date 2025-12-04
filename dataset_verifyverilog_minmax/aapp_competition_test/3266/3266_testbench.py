import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_flow(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    
    test_cases = [
        (4, 5, [(0,1,10), (1,2,1), (1,3,1), (0,2,1), (2,3,10)], 3), # Original flow 3 (scaled down if needed)
        (2, 1, [(0,1,1000)], 1000), # Original 100000 -> 1000 for 16-bit fit
        (2, 1, [(1,0,1000)], 0) # Reversed source/sink
    ]
    passed = 0
    
    # Preload edge memory for each test
    for (n, e, edges, expected) in test_cases:
        dut.node_count.value = n
        dut.edge_count.value = e
        # Load edges into memory (only up to 16)
        for i in range(16):
            if i < len(edges):
                u,v,c = edges[i]
                dut.edges[i].value = (u << 43) | (v << 40) | c
            else:
                dut.edges[i].value = 0
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done or timeout
        for _ in range(300):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            dut._log.error("Timeout waiting for done signal")
        
        if dut.flow.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: Expected {expected}, got {dut.flow.value}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")