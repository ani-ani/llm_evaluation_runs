import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_kahn(dut):
    # Clock generator
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    test_cases = [
        # Test 1: Linear chain (4 nodes) - max S=1
        {
            "n": 4,
            "edges": [(0,1), (1,2), (2,3)],
            "expected": 1
        },
        # Test 2: Diamond (5 nodes) - max S=3
        {
            "n": 5,
            "edges": [(0,4), (1,2), (1,3), (2,4), (3,4)],
            "expected": 3
        },
        # Test 3: Independent nodes (3 nodes) - max S=3
        {
            "n": 3,
            "edges": [],
            "expected": 3
        }
    ]
    
    passed = 0
    for case in test_cases:
        # Initialize inputs
        dut.start.value = 0
        dut.num_nodes.value = case["n"]
        dut.num_edges.value = len(case["edges"])
        
        # Flatten edges (pad unused with 0)
        for i in range(56):
            if i < len(case["edges"]):
                dut.edge_src[i].value = case["edges"][i][0]
                dut.edge_dst[i].value = case["edges"][i][1]
            else:
                dut.edge_src[i].value = 0
                dut.edge_dst[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (wait up to 100 cycles)
        timeout = 100
        while dut.done.value == 0 and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            dut._log.error("Test timed out")
        else:
            if dut.max_S_size.value == case["expected"]:
                passed += 1
                dut._log.info(f"Test passed: Expected {case['expected']}, got {dut.max_S_size.value}")
            else:
                dut._log.error(f"Test failed: Expected {case['expected']}, got {dut.max_S_size.value}")
    
    dut._log.info(f"
SUMMARY: {passed}/{len(test_cases)} tests passed")
