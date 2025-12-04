import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_knight_gen(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        (4, [(0,0), (1,0), (1,3), (2,0)]),
        (7, [(0,0), (1,0), (1,3), (2,0), (3,0), (3,3), (4,0)]),
        (1, [(0,0)]),
        (3, [(0,0), (1,0), (1,3)]),
        (5, [(0,0), (1,0), (1,3), (2,0), (3,0)])
    ]
    passed = 0
    for n_val, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load test case
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        results = []
        timeout = 0
        
        # Collect outputs
        while not dut.done.value and timeout < 25:
            await RisingEdge(dut.clk)
            if dut.valid.value:
                results.append((int(dut.x.value), int(dut.y.value)))
            timeout += 1
        
        # Verify results
        if results == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed for n={n_val}
              Got: {results}
              Expected: {expected}")
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)