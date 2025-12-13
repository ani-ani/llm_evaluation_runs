import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import numpy as np

@cocotb.test()
async def test_transport_switch(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Define scaled test cases (original examples adjusted to 32-bit)
    test_cases = [
        { # Sample Input 1→ Output 2
            "t": 4,
            "n": 4,
            "min_dists": [100, 200, 300, 400],
            "max_angles": [30000, 20000, 10000, 0],
            "dists": [50, 75, 400, 0,0,0,0,0],
            "angles": [10000, 20000, -40000,0,0,0,0,0],
            "expected": 2
        },
        { # Sample Input 2→ Output IMPOSSIBLE (15)
            "t": 1,
            "n": 3,
            "min_dists": [20],
            "max_angles": [50000],
            "dists": [100, 10,0,0,0,0,0,0],
            "angles": [10000, -60000,0,0,0,0,0,0],
            "expected": 15
        },
        { # Edge case: n=1 (no segments)
            "t": 2,
            "n": 1,
            "min_dists": [10,20],
            "max_angles": [1000,2000],
            "dists": [0,0,0,0,0,0,0,0],
            "angles": [0,0,0,0,0,0,0,0],
            "expected": 0
        }
    ]
    
    passed = 0
    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.t.value = case["t"]
        dut.n.value = case["n"]
        for i in range(4):
            dut.min_dists[i].value = case["min_dists"][i] if i < len(case["min_dists"]) else 0
            dut.max_angles[i].value = case["max_angles"][i] if i < len(case["max_angles"]) else 0
        for i in range(8):
            dut.dists[i].value = case["dists"][i]
            dut.angles[i].value = case["angles"][i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 20 cycles)
        timeout = 0
        while not dut.done.value and timeout < 25:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 25:
            dut._log.error("Test timed out")
        else:
            if dut.switch_count.value == case["expected"]:
                passed += 1
            else:
                dut._log.error(f"Failed: Expected {case['expected']}, got {dut.switch_count.value}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")