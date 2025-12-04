import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_vertex_controller(dut):
    # Convert float to Q16.16 fixed-point
    def to_fixed(x):
        return int(x * (1 << 16))
    
    # Test cases (scaled to 5 nodes)
    test_cases = [
        {
            "input": {
                "n": 5,
                "vertex_vals": [2, 5, 1, 4, 6, 0, 0, 0],
                "edges": [1, 1, 3, 3]
            },
            "output": [1, 0, 1, 0, 0, 0, 0, 0]
        },
        {
            "input": {
                "n": 5,
                "vertex_vals": [9, 7, 8, 6, 5, 0, 0, 0],
                "edges": [1, 2, 3, 4]
            },
            "output": [4, 3, 2, 1, 0, 0, 0, 0]
        },
        {
            "input": {
                "n": 1,
                "vertex_vals": [1, 0, 0, 0, 0, 0, 0, 0],
                "edges": [0, 0, 0, 0, 0, 0, 0]  // Unused
            },
            "output": [0, 0, 0, 0, 0, 0, 0, 0]
        }
    ]
    
    # Clock generator
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    passed = 0
    for test_idx, test in enumerate(test_cases):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        for i in range(8):
            dut.vertex_vals[i].value = to_fixed(test["input"]["vertex_vals"][i])
        for i in range(7):
            dut.edge_weights[i].value = to_fixed(test["input"]["edges"][i])
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check outputs
        correct = True
        for i in range(8):
            if i < test["input"]["n"]:
                if dut.control_counts[i].value != test["output"][i]:
                    dut._log.error(f"Test {test_idx} failed at vertex {i}: Expected {test['output'][i]}, Got {dut.control_counts[i].value}")
                    correct = False
        
        if correct:
            passed += 1
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
