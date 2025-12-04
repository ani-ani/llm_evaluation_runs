import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_pairs(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1 (8-node tree with 4 universities)
    # Towns [1,2,3,4,5,6,7,8] - Univs at [1,5,6,2] (binary:10100011)
    # Edges: [0-2][2-1][3-4][2-6][3-2][3-5] (0=node1,1=node2,...,7=node8)
    test_cases = [
        {
            "adj": 
                [0, 5, 2, 1, 0, 0, 0, 0],   // node0 connects to 5,2 
                [2, 0, 0, 0, 0, 0, 0, 0],   // node1 connects to 2 
                [0, 1, 0, 3, 0, 0, 0, 0],   // node2 connects to 0,1 
                [0, 0, 4, 0, 5, 7, 0, 0],   // node3 connects to 2,4,5,7 
                [3, 0, 0, 0, 0, 0, 0, 0],   // node4 connects to 3 
                [3, 0, 0, 0, 0, 0, 0, 0],   // node5 connects to 3 
                [0, 0, 0, 0, 0, 0, 0, 0],   // node6 unused 
                [3, 0, 0, 0, 0, 0, 0, 0],   // node7 connects to 3 
            "univ": 0b10100011,  # Univs at nodes 0,1,5,7 
            "n": 7,  # Actual nodes used (0-6)
            "expected": 6
        },
        {
            "adj": 
                [1, 2, 0, 0, 0, 0, 0, 0],  // Simple 2-node tree 
                [0, 0, 0, 0, 0, 0, 0, 0], 
                [0]*8, [0]*8, [0]*8, [0]*8, [0]*8, [0]*8,
            "univ": 0b00000011,  # Univs at nodes 0,1 
            "n": 2,                 
            "expected": 1
        },
        {
            "adj": 
                [1, 3, 0, 0, 0, 0, 0, 0], # Node0 (1,3)
                [0, 0, 0, 0, 0, 0, 0, 0], # Node1
                [0]*8,                    # Node2 unused 
                [0, 4, 5, 0, 0, 0, 0, 0], # Node3 (0,4,5)
                [3, 0, 0, 0, 0, 0, 0, 0], # Node4 (3)
                [3, 0, 0, 0, 0, 0, 0, 0], # Node5 (3)
                [0]*8, [0]*8, 
            "univ": 0b01100101,  # Univs at 0,2,5,7 
            "n": 6,
            "expected": 6
        }
    ]
    
    passed = 0
    for case in test_cases:
        # Load adjacency list
        for i in range(8):
            dut.adj_list[i].value = case["adj"][i]
        
        dut.univ_mask.value = case["univ"]
        dut.node_count.value = case["n"]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 20 cycles)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure("Timeout waiting for done")
        
        if dut.max_sum.value == case["expected"]:
            passed += 1
            dut._log.info(f"Test passed: {dut.max_sum.value} == {case['expected']}")
        else:
            dut._log.error(f"Test failed: Got {dut.max_sum.value}, expected {case['expected']}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    if passed != len(test_cases):
        raise TestFailure("Some tests failed")
