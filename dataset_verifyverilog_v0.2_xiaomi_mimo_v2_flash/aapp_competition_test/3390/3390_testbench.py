import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_longest_menu(dut):
    """Test the longest_menu module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_nodes.value = 0
    for i in range(8):
        for j in range(8):
            dut.adjacency_matrix[i][j] = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 4 nodes, edges: 1->2, 2->3, 2->4
    # Expected: path 1-2-3 or 1-2-4 (length 3)
    dut.num_nodes.value = 4
    dut.adjacency_matrix[0][1] = 1  # 1->2
    dut.adjacency_matrix[1][2] = 1  # 2->3
    dut.adjacency_matrix[1][3] = 1  # 2->4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (up to 256 cycles)
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 1: Done signal not asserted within timeout")
    
    if dut.result.value != 3:
        raise TestFailure(f"Test 1: Expected 3, got {dut.result.value}")
    
    print("Test 1 passed: 4 nodes, got result 3")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: 7 nodes, edges: 1->2, 2->3, 3->4, 4->5, 5->2, 4->6, 5->7
    # Expected: path 1-2-3-4-6 (length 5) or 1-2-3-4-5-7 (length 6)
    # Actually 1-2-3-4-5-7 = 6 nodes
    dut.num_nodes.value = 7
    dut.adjacency_matrix[0][1] = 1  # 1->2
    dut.adjacency_matrix[1][2] = 1  # 2->3
    dut.adjacency_matrix[2][3] = 1  # 3->4
    dut.adjacency_matrix[3][4] = 1  # 4->5
    dut.adjacency_matrix[4][1] = 1  # 5->2 (cycle)
    dut.adjacency_matrix[3][5] = 1  # 4->6
    dut.adjacency_matrix[4][6] = 1  # 5->7
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 2: Done signal not asserted within timeout")
    
    if dut.result.value != 6:
        raise TestFailure(f"Test 2: Expected 6, got {dut.result.value}")
    
    print("Test 2 passed: 7 nodes, got result 6")
    
    # Test case 3: Single node (edge case)
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_nodes.value = 1
    dut.adjacency_matrix[0][0] = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 3: Done signal not asserted within timeout")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 3: Expected 1, got {dut.result.value}")
    
    print("Test 3 passed: 1 node, got result 1")
    
    # Test case 4: Chain of 3 nodes
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_nodes.value = 3
    for i in range(8):
        for j in range(8):
            dut.adjacency_matrix[i][j] = 0
    dut.adjacency_matrix[0][1] = 1
    dut.adjacency_matrix[1][2] = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 4: Done signal not asserted within timeout")
    
    if dut.result.value != 3:
        raise TestFailure(f"Test 4: Expected 3, got {dut.result.value}")
    
    print("Test 4 passed: Chain of 3, got result 3")
    
    print("
All tests passed!")
    
    # Print summary
    total_tests = 4
    passed_tests = 4
    print(f"
Summary: {passed_tests}/{total_tests} tests passed")
