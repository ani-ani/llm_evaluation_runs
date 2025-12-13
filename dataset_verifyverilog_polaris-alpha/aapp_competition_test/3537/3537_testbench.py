import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from cocotb.utils import get_sim_time
import numpy as np

@cocotb.test()
async def test_travel(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await Timer(15, units="ns")
    
    # Sample test cases (scaled)
    test_cases = [
        {   # Sample Input 1 (5 countries, 8 flights)
            "n": 5,
            "flights": [ 
                [1,2,1,10], [2,4,11,16], [2,1,9,12], [3,5,28,100],
                [1,2,3,8], [4,3,20,21], [1,3,13,27], [3,5,23,24] 
            ],
            "expected": 12
        },
        {   # Sample Input 2 (3 countries, 5 flights)
            "n": 3,
            "flights": [ 
                [1,1,10,20], [1,2,30,40], [1,2,50,60], [1,2,70,80], [2,3,90,95] 
            ],
            "expected": 1900
        }
    ]
    
    passed = 0
    for idx, case in enumerate(test_cases):
        # Reset pulse
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.target_n.value = case['n'] - 1  # 0-based addressing
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load flight table (all structs as 32-bit packed)
        for i in range(8):
            if i < len(case['flights']):
                a,b,s,e = case['flights'][i]
                packed = (a << 29) | (b << 26) | (s << 19) | (e << 12)
                dut.flight_table[i][0].value = packed  # Assuming array access syntax)
            else:
                dut.flight_table[i][0].value = 0  # Empty flight slot
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 20 cycles)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        if dut.done.value == 1:
            result = dut.min_frustration.value.integer
            if result == case['expected']:
                passed += 1
                dut._log.info(f"Test case {idx+1} PASSED (result={result})")
            else:
                dut._log.error(f"Test case {idx+1} FAILED. Expected: {case['expected']}, Got: {result}")
        else:
            dut._log.error(f"Test case {idx+1} TIMEOUT")
        
        # Reset for next test case
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
