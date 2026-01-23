import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_chromatic_number_solver(dut):
    """Test the chromatic number solver module."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_vertices.value = 0
    for i in range(8):
        for j in range(8):
            dut.adjacency_matrix[i][j].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 4 nodes, K=3 (Star graph with center + 3 leaves, or Triangle + isolated... Sample 1 is Triangle + Leaf?)
    # Sample 1: 
    # 0: 1 2
    # 1: 0 2 3
    # 2: 0 1
    # 3: 1
    # This is a K3 (0,1,2) plus edge (1,3). K=3.
    dut.num_vertices.value = 4
    matrix = [
        [0, 1, 1, 0],
        [1, 0, 1, 1],
        [1, 1, 0, 0],
        [0, 1, 0, 0]
    ]
    for i in range(4):
        for j in range(4):
            dut.adjacency_matrix[i][j].value = matrix[i][j]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.chromatic_number.value == 3, f"TC1 Failed: Expected 3, got {dut.chromatic_number.value}"
    print(f"TC1 Passed: Result {dut.chromatic_number.value}")
    await RisingEdge(dut.clk)
    
    # Test Case 2: Bipartite graph, K=2
    # 5 nodes. 0,1 connected to 2,3,4. No edges within {0,1} or {2,3,4}.
    dut.num_vertices.value = 5
    matrix = [
        [0, 0, 1, 1, 1],
        [0, 0, 1, 1, 1],
        [1, 1, 0, 0, 0],
        [1, 1, 0, 0, 0],
        [1, 1, 0, 0, 0]
    ]
    for i in range(5):
        for j in range(5):
            dut.adjacency_matrix[i][j].value = matrix[i][j]
    for i in range(5, 8):
        for j in range(8):
            dut.adjacency_matrix[i][j].value = 0
            dut.adjacency_matrix[j][i].value = 0
            
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.chromatic_number.value == 2, f"TC2 Failed: Expected 2, got {dut.chromatic_number.value}"
    print(f"TC2 Passed: Result {dut.chromatic_number.value}")
    await RisingEdge(dut.clk)

    # Test Case 3: Triangle (3 nodes), K=3
    # 3 nodes: 0-1, 1-2, 2-0
    dut.num_vertices.value = 3
    matrix = [
        [0, 1, 1],
        [1, 0, 1],
        [1, 1, 0]
    ]
    for i in range(3):
        for j in range(3):
            dut.adjacency_matrix[i][j].value = matrix[i][j]
    for i in range(3, 8):
        for j in range(8):
            dut.adjacency_matrix[i][j].value = 0
            dut.adjacency_matrix[j][i].value = 0
            
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.chromatic_number.value == 3, f"TC3 Failed: Expected 3, got {dut.chromatic_number.value}"
    print(f"TC3 Passed: Result {dut.chromatic_number.value}")
    await RisingEdge(dut.clk)
    
    # Test Case 4: Path of 3 nodes, K=2
    # 3 nodes: 0-1-2
    dut.num_vertices.value = 3
    matrix = [
        [0, 1, 0],
        [1, 0, 1],
        [0, 1, 0]
    ]
    for i in range(3):
        for j in range(3):
            dut.adjacency_matrix[i][j].value = matrix[i][j]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.chromatic_number.value == 2, f"TC4 Failed: Expected 2, got {dut.chromatic_number.value}"
    print(f"TC4 Passed: Result {dut.chromatic_number.value}")
    await RisingEdge(dut.clk)

    # Test Case 5: 4 nodes, K=4 (K4, complete graph)
    # 4 nodes: all connected to all others
    dut.num_vertices.value = 4
    matrix = [
        [0, 1, 1, 1],
        [1, 0, 1, 1],
        [1, 1, 0, 1],
        [1, 1, 1, 0]
    ]
    for i in range(4):
        for j in range(4):
            dut.adjacency_matrix[i][j].value = matrix[i][j]
    for i in range(4, 8):
        for j in range(8):
            dut.adjacency_matrix[i][j].value = 0
            dut.adjacency_matrix[j][i].value = 0
            
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.chromatic_number.value == 4, f"TC5 Failed: Expected 4, got {dut.chromatic_number.value}"
    print(f"TC5 Passed: Result {dut.chromatic_number.value}")
    await RisingEdge(dut.clk)

    print("All tests passed!")
