import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_longest_race_path(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper to initialize adjacency matrix
    def set_adj_matrix(edges):
        # Initialize to 0
        for i in range(8):
            for j in range(8):
                dut.adj_matrix[i][j].value = 0
        # Set edges
        for u, v in edges:
            # Map 1-based input to 0-based hardware (except 1->1 mapping)
            # If problem uses 1..N, and we use 0..N-1, 1 becomes 1 (index 1)
            # Node 1 is index 1. Node 0 is unused in 1-based.
            # Let's stick to 1-based indices for the matrix for simplicity in mapping.
            # Hardware expects 0..7. Input is 1..N.
            # Let's map input 1->1, 2->2, ..., 7->7. Index 0 unused.
            # Matrix indices in Verilog are 0..7. So we set index u and v directly.
            dut.adj_matrix[u][v].value = 1
            dut.adj_matrix[v][u].value = 1

    # Test Case 1: Sample 1 (Nodes 1,2,3,4)
    # Edges: (1,2), (1,3), (2,4)
    # Valid paths ending at 1:
    # 2 -> 1 (Length 1)
    # 3 -> 1 (Length 1)
    # 4 -> 2 -> 1 (Length 2)
    # Longest: 2
    dut._log.info("Running Test Case 1")
    set_adj_matrix([(1, 2), (1, 3), (2, 4)])
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.max_length.value != 2:
        raise TestFailure(f"Expected 2, got {dut.max_length.value}")
    dut._log.info(f"Test 1 Passed: {dut.max_length.value}")

    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: Sample 2 (Nodes 1..6)
    # Edges: (1,2), (1,3), (2,4), (3,4), (3,5), (5,6)
    # Longest path ending at 1: 6 -> 5 -> 3 -> 4 -> 2 -> 1 (Length 5)
    # Or 6 -> 5 -> 3 -> 1 (Length 3)
    # Or 4 -> 2 -> 1 (Length 2)
    # Longest: 5
    dut._log.info("Running Test Case 2")
    set_adj_matrix([(1, 2), (1, 3), (2, 4), (3, 4), (3, 5), (5, 6)])
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.max_length.value != 5:
        raise TestFailure(f"Expected 5, got {dut.max_length.value}")
    dut._log.info(f"Test 2 Passed: {dut.max_length.value}")

    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 3: Sample 3 (Nodes 1..5)
    # Edges: (1,2), (2,3), (3,4), (4,5), (5,3), (3,1)
    # This graph has a cycle 1-2-3-4-5-3-1? No, edges: 1-2, 2-3, 3-4, 4-5, 5-3, 3-1
    # Structure: 1 connects to 2 and 3. 2 connects to 1 and 3. 3 connects to 1,2,4,5. 4 connects to 3,5. 5 connects to 3,4.
    # This is a graph with triangles and quads.
    # Longest path ending at 1:
    # 4 -> 5 -> 3 -> 2 -> 1 (Edges 4-5, 5-3, 3-2, 2-1) -> Length 4
    # 5 -> 4 -> 3 -> 2 -> 1 (Edges 5-4, 4-3, 3-2, 2-1) -> Length 4
    # Wait, let's trace carefully.
    # Possible path: Start 4 -> 5 -> 3 -> 1 (Length 3)
    # Start 4 -> 5 -> 3 -> 2 -> 1 (Length 4)
    # Start 5 -> 4 -> 3 -> 1 (Length 3)
    # Start 5 -> 4 -> 3 -> 2 -> 1 (Length 4)
    # Wait, the output in the prompt says 6. Let me check.
    # Ah, the example output 6 might imply a longer path or I'm missing something.
    # Let's check the graph again: 1-2, 2-3, 3-4, 4-5, 5-3, 3-1.
    # Nodes: 1, 2, 3, 4, 5.
    # Path: 4 -> 5 -> 3 -> 1 is length 3.
    # Path: 4 -> 5 -> 3 -> 2 -> 1 is length 4.
    # Path: 4 -> 5 -> 3 -> 4 -> 5 -> 3 -> 2 -> 1 -> NO, edge repetition.
    # Let's assume the example output 6 is correct for a complex path.
    # Actually, looking at the graph: 1-2-3 is a triangle. 3-4-5 is a triangle (3-4, 4-5, 5-3).
    # 1 is connected to 2 and 3.
    # To get length 6: 4 -> 5 -> 3 -> 2 -> 1 -> ? No, must end at 1.
    # Maybe 4 -> 5 -> 3 -> 4 -> 5 -> 3 -> 2 -> 1? No edge repetition.
    # Maybe the graph allows: 4 -> 5 -> 3 -> 4 -> 3 -> 2 -> 1? No edge 3-4 repeated.
    # Let's assume the problem statement output 6 is correct and I'm misinterpreting the constraints or graph.
    # However, for hardware verification, we will use the logic implemented.
    # If the hardware logic finds 4, but the example says 6, I should check the graph.
    # Graph: 1-2, 2-3, 3-4, 4-5, 5-3, 3-1.
    # Wait, is it 1-2, 2-3, 3-4, 4-5, 5-3, 3-1? Yes.
    # Path: 4 -> 5 -> 3 -> 4? No.
    # Path: 4 -> 5 -> 3 -> 2 -> 1. (Edges: 4-5, 5-3, 3-2, 2-1). Length 4.
    # Path: 4 -> 3 -> 5 -> 4 -> 3 -> 2 -> 1? Edges 4-3, 3-5, 5-4, 4-3. 4-3 repeated. No.
    # Path: 4 -> 3 -> 1 -> 2 -> 3 -> 5 -> 4 -> 3 -> 2 -> 1? Many repeats.
    # Let's assume the Python code's output is correct for its implementation.
    # I will stick to verifying the expected logic of a simple path finding algorithm.
    # Given the constraint "every road in the network is part of at most one ring", it's a cactus graph.
    # For cactus graphs, longest path can be found efficiently.
    # But here we are doing brute force for small N=8.
    # Let's use a test case where the longest path is clearly defined.
    # Example 3 in prompt says Output 6. Let's try to construct a path of length 6 for that graph.
    # Nodes 1..5. Edges: (1,2), (2,3), (3,4), (4,5), (5,3), (3,1).
    # Wait, the example input says "5 6" but the list has 6 edges. 5 nodes, 6 edges.
    # Path: 4 -> 5 -> 3 -> 4? No.
    # Path: 4 -> 5 -> 3 -> 2 -> 1. Length 4.
    # Path: 4 -> 3 -> 5 -> 4? No.
    # Path: 4 -> 3 -> 2 -> 1 -> 3 -> 5 -> 4? No edge 1-3 repeated.
    # Let's re-read: "The path may visit a city more than once, but it must not contain any road more than once."
    # Graph: 1-2, 2-3, 3-4, 4-5, 5-3, 3-1.
    # Let's try path: 4 -> 5 -> 3 -> 4? No.
    # Path: 4 -> 3 -> 5 -> 4? No.
    # Path: 4 -> 3 -> 2 -> 1 -> 3 -> 5 -> 4? Edge 3-1 and 1-3? No.
    # Wait, 1-2-3-1 is a triangle. 3-4-5-3 is a triangle.
    # Let's try: 4 -> 5 -> 3 -> 4 -> 5 -> 3 -> 2 -> 1? No.
    # Maybe I am misreading the edges. "5 6" then edges.
    # Edges: 1-2, 2-3, 3-4, 4-5, 5-3, 3-1. 
    # Let's try: 4 -> 3 -> 1 -> 2 -> 3 -> 5 -> 4? Edge 3-4 used, 4-5 used, 5-3 used, 3-2 used, 2-1 used, 1-3 used.
    # Length 6. Wait, 4-3, 3-1, 1-2, 2-3 (repeats 2-3? No, 2-3 is edge, 3-2 is same edge).
    # Edge repetition check: 2-3 is in the list. 3-2 is the same.
    # Path: 4 -> 3 -> 1 -> 2 -> 3 -> 5 -> 4. 
    # Edges: (4,3), (3,1), (1,2), (2,3), (3,5), (5,4). 
    # Edge (3,5) is used, (4,5) is used? No, 5-4 is used. 
    # Does edge (5,4) exist? Yes, line "4 5".
    # Let's check edges again: 1-2, 2-3, 3-4, 4-5, 5-3, 3-1. 
    # Edges: E1(1,2), E2(2,3), E3(3,4), E4(4,5), E5(5,3), E6(3,1).
    # Path: 4 -> 3 -> 1 -> 2 -> 3 -> 5 -> 4. 
    # Step 1: 4-3 (E3). Step 2: 3-1 (E6). Step 3: 1-2 (E1). Step 4: 2-3 (E2). Step 5: 3-5 (E5). Step 6: 5-4 (E4). 
    # Valid! Length 6. Ends at 4. Wait, must end at 1.
    # Path must end at 1.
    # 4 -> 3 -> 5 -> 4 -> 3 -> 2 -> 1. 
    # Edges: (4,3), (3,5), (5,4), (4,3) -> REPEAT.
    # 4 -> 3 -> 1 -> 2 -> 3 -> 5 -> 3 -> 1? Edges: (4,3), (3,1), (1,2), (2,3), (3,5), (5,3) -> REPEAT (3,5).
    # 5 -> 3 -> 4 -> 5 -> 3 -> 2 -> 1. Edges: (5,3), (3,4), (4,5) -> REPEAT.
    # Okay, maybe the path is 4 -> 3 -> 1 -> 2 -> 3 -> 5 -> 3 -> 1? No.
    # Let's trust the Python code output. 
    # I will modify Test Case 3 to be simpler to verify or trust the specific path found.
    # Given the complexity of tracing that specific path, let's use a slightly different graph for Test 3 that is clearer, or stick to the logic.
    # Actually, the path 4 -> 3 -> 1 -> 2 -> 3 -> 5 -> 3 -> 1 is length 7? No, edges: (4,3), (3,1), (1,2), (2,3), (3,5), (5,3), (3,1). (5,3) repeats if 3-5 was used. 
    # Let's assume the python code correctly calculates 6 for that graph.
    # We will verify the hardware against the expected output of 6.
    dut._log.info("Running Test Case 3")
    set_adj_matrix([(1, 2), (2, 3), (3, 4), (4, 5), (5, 3), (3, 1)])
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Expected output is 6 based on prompt example
    if dut.max_length.value != 6:
        # For debugging: print what it found
        dut._log.warning(f"Expected 6, got {dut.max_length.value}. Checking if logic is consistent with implementation.")
        # In a real scenario, we would debug here. For now, raise failure if mismatch.
        # But wait, let's verify the path of length 6 exists.
        # 1-2-3-4-5-3-1? Edges: (1,2), (2,3), (3,4), (4,5), (5,3), (3,1). Length 6. Ends at 1.
        # Path: 1 -> 2 -> 3 -> 4 -> 5 -> 3 -> 1. 
        # Edges used: (1,2), (2,3), (3,4), (4,5), (5,3), (3,1). All distinct. 
        # Yes, length 6. So hardware should find 6.
        raise TestFailure(f"Expected 6, got {dut.max_length.value}")
    dut._log.info(f"Test 3 Passed: {dut.max_length.value}")

    # Add a small graph test for sanity
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 4: Triangle (1-2-3)
    # Edges: (1,2), (2,3), (3,1)
    # Path: 2 -> 1 (1), 3 -> 1 (1), 2 -> 3 -> 1 (2)
    # Longest: 2
    dut._log.info("Running Test Case 4")
    set_adj_matrix([(1, 2), (2, 3), (3, 1)])
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.max_length.value != 2:
        raise TestFailure(f"Expected 2, got {dut.max_length.value}")
    dut._log.info(f"Test 4 Passed: {dut.max_length.value}")
