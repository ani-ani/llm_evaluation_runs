import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_tree_checker(dut):
    """Test tree checker logic"""
    
    # Helper function to set inputs
    def set_inputs(n, edges):
        dut.n.value = n
        dut.num_edges.value = len(edges)
        # Pad arrays to max size (16)
        max_edges = 16
        for i in range(max_edges):
            if i < len(edges):
                dut.edge_u[i].value = edges[i][0]
                dut.edge_v[i].value = edges[i][1]
            else:
                dut.edge_u[i].value = 0
                dut.edge_v[i].value = 0
    
    # Helper function to check result
    def check_result(expected):
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Expected {expected}, got {actual}")
    
    print("Starting tests...")
    
    # Test Case 1: n=2, edge (0,1) - Always YES
    print("Test 1: n=2")
    set_inputs(2, [(0, 1)])
    await Timer(10, units='ns')
    check_result(1) # YES
    
    # Test Case 2: n=3, path 0-1-2 (degrees: 1, 2, 1) - Should be NO
    print("Test 2: n=3, path")
    set_inputs(3, [(0, 1), (1, 2)])
    await Timer(10, units='ns')
    check_result(0) # NO
    
    # Test Case 3: n=5, star with extra edge (1-2-5, 1-3, 1-4) - Node 1 degree 3, Node 2 degree 2 - NO
    # Nodes: 0,1,2,3,4. Edges: (1,0), (1,2), (1,3), (0,4) -> degrees: 2, 3, 1, 1, 1 -> NO
    print("Test 3: n=5, node with degree 2")
    set_inputs(5, [(1, 0), (1, 2), (1, 3), (0, 4)])
    await Timer(10, units='ns')
    check_result(0) # NO
    
    # Test Case 4: n=6, star-like (1 is hub, 2 has children) - Degrees: 3, 3, 1, 1, 1, 1 -> YES
    # 0-1, 1-2, 1-3, 2-4, 2-5. Degrees: 1, 3, 3, 1, 1, 1 -> YES
    print("Test 4: n=6, no degree 2")
    set_inputs(6, [(0, 1), (1, 2), (1, 3), (2, 4), (2, 5)])
    await Timer(10, units='ns')
    check_result(1) # YES
    
    # Test Case 5: n=4, star 0-1, 0-2, 0-3 - Degrees: 3, 1, 1, 1 -> YES
    print("Test 5: n=4, star")
    set_inputs(4, [(0, 1), (0, 2), (0, 3)])
    await Timer(10, units='ns')
    check_result(1) # YES
    
    # Test Case 6: n=3, star 0-1, 0-2 - Degrees: 2, 1, 1 -> NO
    print("Test 6: n=3, star")
    set_inputs(3, [(0, 1), (0, 2)])
    await Timer(10, units='ns')
    check_result(0) # NO
    
    print("All tests passed!")
