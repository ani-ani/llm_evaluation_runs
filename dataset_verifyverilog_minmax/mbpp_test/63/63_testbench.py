import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from cocotb.utils import get_sim_time
import numpy as np

@cocotb.test()
async def test_max_diff(dut):
    # Flatten test cases to 8 pair format (pad with zeros if needed)
    test_cases = [
        {'input': [(3,5), (1,7), (10,3), (1,2)] + [(0,0)]*4, 'expected': 7},
        {'input': [(4,6), (2,17), (9,13), (11,12)] + [(0,0)]*4, 'expected': 15},
        {'input': [(12,35), (21,27), (13,23), (41,22)] + [(0,0)]*4, 'expected': 23}
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    passed = 0
    total = len(test_cases)
    
    for case in test_cases:
        # Reset device
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Flatten input pairs into bit vector [a0,b0,a1,b1,...,a7,b7]
        # Each element packed into 6 bits
        flattened = [ ]
        for (a, b) in case['input']:
            flattened.append(a)
            flattened.append(b)
        
        # Assign flattened array to input
        for i in range(16):
            dut.pairs.value[i*6 +:6] = flattened[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for 8 cycles
        for _ in range(8):
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.done.value == 1 and dut.max_diff.value == case['expected']:
            passed += 1
            dut._log.info(f"PASS: {case['input']} -> {dut.max_diff.value}")
        else:
            dut._log.error(f"FAIL: {case['input']} -> {dut.max_diff.value}, expected {case['expected']}")
        
        # Add cycle between tests
        await RisingEdge(dut.clk)
        
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total