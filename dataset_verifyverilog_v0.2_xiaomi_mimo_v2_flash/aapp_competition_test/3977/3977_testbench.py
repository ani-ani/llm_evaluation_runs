import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge

@cocotb.test()
async def test_stable_graph_max_edges(dut):
    """Test the stable_graph_max_edges module"""
    
    # Helper to convert edge list to adjacency matrix for N=8
    def get_adj_matrix(edges, n=8):
        mat = [[0]*n for _ in range(n)]
        for u, v in edges:
            # Convert 1-based input to 0-based internal
            u -= 1
            v -= 1
            if 0 <= u < n and 0 <= v < n:
                mat[u][v] = 1
                mat[v][u] = 1
        return mat

    # Test cases: (gov_nodes, edges, expected_add)
    # Gov nodes are 1-based indices
    # Edges are tuples (u, v) 1-based
    # Expected output is the number of edges to add
    test_cases = [
        # Case 1: 4 nodes, 1 edge, 2 gov. Govs: 1, 3. Edge: 1-2. 
        # Component 1 (gov): 1, 2 (size 2). Component 2 (gov): 3 (size 1). Component 3 (non-gov): 4 (size 1).
        # Gov sum: C(2)+C(1) = 1+0 = 1. Max gov = 2. Non gov = 1.
        # Total edges (merged): C(2+1) + C(1) = C(3) + 0 = 3. 
        # Existing edges = 1. Result = 3 - 1 = 2. Correct.
        ([1, 3], [(1, 2)], 2),
        
        # Case 2: 3 nodes, 3 edges, 1 gov. Gov: 2. Edges: 1-2, 1-3, 2-3.
        # Component: 1,2,3. Gov: Yes. Size 3.
        # Gov sum: C(3) = 3. Max gov = 3. Non gov = 0.
        # Total edges: C(3+0) = 3. Existing = 3. Result = 0. Correct.
        ([2], [(1, 2), (1, 3), (2, 3)], 0),

        # Case 3: 10 3 2
        # Gov: 1, 10. Edges: 1-2, 1-3, 4-5.
        # Gov 1 component: 1, 2, 3 (size 3).
        # Gov 10 component: 10 (size 1).
        # Non-gov component: 4, 5 (size 2). Nodes 6,7,8,9 are isolated (size 1 each). Total non-gov = 2 + 4 = 6.
        # Gov sum: C(3)+C(1) = 3+0 = 3.
        # Max gov = 3. Non gov = 6.
        # Total edges: C(3+6) + C(1) = C(9) + 0 = 36.
        # Existing = 3. Result = 33.
        # Note: The provided test case says 33. Let's verify: 1-2, 1-3, 4-5.
        # Comp 1: {1,2,3} size 3.
        # Comp 2: {10} size 1.
        # Comp 3: {4,5} size 2.
        # Isolated: {6}, {7}, {8}, {9} size 1 each.
        # We merge Comp 3 and Isolated into Comp 1.
        # New Comp 1 size = 3 + 2 + 4 = 9. Edges = 9*8/2 = 36.
        # Comp 2 size = 1. Edges = 0.
        # Total edges = 36. Existing = 3. Added = 33. Correct.
        ([1, 10], [(1, 2), (1, 3), (4, 5)], 33),
        
        # Case 4: 1 node, 0 edges, 1 gov. Gov: 1.
        # Comp: {1}. Size 1.
        # Gov sum: C(1)=0. Max gov=1. Non gov=0.
        # Total: C(1)=0. Existing=0. Added=0.
        ([1], [], 0),

        # Case 5: 1000 0 1 (Scaled down to N=8 for HDL test, but logic handles 8 max)
        # Let's make a max capacity test for N=8.
        # 8 nodes, 0 edges, 1 gov. Gov: 1.
        # Comp 1: {1} size 1.
        # Non gov: {2..8} size 7.
        # Gov sum: C(1)=0. Max gov=1. Non gov=7.
        # Total: C(1+7) = C(8) = 28. Existing=0. Added=28.
        # Note: The provided case 5 output is 499500 (for n=1000). We scale to 28.
        ([1], [], 28) 
    ]

    for i, (govs, edges, expected) in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}: Govs={govs}, Edges={edges}, Expected={expected}")
        
        # Prepare inputs for N=8
        n = 8
        
        # Generate gov_mask
        gov_mask = 0
        for g in govs:
            if g <= n:
                gov_mask |= (1 << (g-1))
        
        # Generate adj_matrix
        adj = get_adj_matrix(edges, n)
        
        # Assign inputs
        # dut.gov_mask is likely a LogicArray
        dut.gov_mask.value = gov_mask
        
        # dut.adj_matrix is [8][8]
        for row in range(n):
            for col in range(n):
                # Accessing 2D array in cocotb depends on version, usually dut.adj_matrix[row][col]
                try:
                    dut.adj_matrix[row][col].value = adj[row][col]
                except:
                    # Fallback for flattened indexing or different naming if necessary
                    # Assuming standard 2D unpacked array
                    pass
        
        # Allow combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.max_edges.value)
        
        assert result == expected, f"Test {i+1} Failed: expected {expected}, got {result}"

    dut._log.info("All tests passed")
