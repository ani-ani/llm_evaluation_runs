import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

# Helper to solve reference for 8-node max
# Returns result for a specific adjacency matrix
def solve_reference(adj):
    n = 8
    # Forward DP: dist from i to end (longest path starting at i)
    fwd = [0] * n
    # Since it's a DAG (assumed), we can process in reverse topological order (n-1 to 0)
    # But for small N, simple relaxation works
    for _ in range(n):
        for u in range(n):
            for v in range(n):
                if adj[u][v]:
                    fwd[u] = max(fwd[u], 1 + fwd[v])
    
    # Backward DP: dist from start to i (longest path ending at i)
    bwd = [0] * n
    for _ in range(n):
        for v in range(n):
            for u in range(n):
                if adj[u][v]:
                    bwd[v] = max(bwd[v], 1 + bwd[u])
    
    # Global max path
    max_len = 0
    for i in range(n):
        # Path could be just a node, length 0. But edges count as length.
        # Actually, path length is number of edges. 
        # Max length is max(fwd[i]) or max over edges: bwd[u] + 1 + fwd[v]
        for u in range(n):
            for v in range(n):
                if adj[u][v]:
                    max_len = max(max_len, bwd[u] + 1 + fwd[v])
    
    if max_len == 0:
        return 0

    # Try removing each edge
    min_after_block = max_len
    
    for u in range(n):
        for v in range(n):
            if adj[u][v]:
                # Remove edge u->v
                # Calculate new max length. 
                # We need to know if u->v was critical for max_len.
                # Check if bwd[u] + 1 + fwd[v] == max_len
                # If so, new max might be max( max_len_before_this_path, bwd[u], fwd[v] )
                # Or other parallel paths.
                # Let's compute exact new max for this removal (re-run DP without edge)
                # But simpler: if critical, new max is max of:
                # 1. max_len from other edges (hard to track)
                # 2. max path ending at u
                # 3. max path starting at v
                # 4. max path that doesn't use u->v
                
                # To be precise, we iterate all pairs again
                cur_max = 0
                for x in range(n):
                    for y in range(n):
                        if adj[x][y]:
                            if x == u and y == v: continue
                            cur_max = max(cur_max, bwd[x] + 1 + fwd[y])
                
                # Also need to account for paths that were strictly dependent on u->v but not u->v itself?
                # No, removing u->v only breaks paths using it. 
                # But fwd/bwd arrays are global. We need to recompute if we want strict accuracy.
                # However, problem constraints are small in adaptation (8 nodes).
                # Let's just re-run the DP for every removal to be safe.
                
                # Optimization: Only recompute if edge is on a max path to avoid O(N^5)
                # But 8 nodes is tiny, O(N^4) is fine.
                
                # Re-run DP simulation for this specific removal
                adj[u][v] = False
                # Compute new max
                f = [0] * n
                for _ in range(n):
                    for i in range(n):
                        for j in range(n):
                            if adj[i][j]:
                                f[i] = max(f[i], 1 + f[j])
                b = [0] * n
                for _ in range(n):
                    for j in range(n):
                        for i in range(n):
                            if adj[i][j]:
                                b[j] = max(b[j], 1 + b[i])
                
                new_max = 0
                for i in range(n):
                    for j in range(n):
                        if adj[i][j]:
                            new_max = max(new_max, b[i] + 1 + f[j])
                
                min_after_block = min(min_after_block, new_max)
                adj[u][v] = True
                
    return min_after_block

@cocotb.test()
async def test_graph_race_solver(dut):
    """Test graph race solver with various small graphs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.adj_matrix_flat.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled to 8x8)
    # 1. Sample 1: 4 nodes -> map to 8 (expand)
    # 1->2, 1->3, 3->4, 2->4. Max path: 1->2->4 (len 2) or 1->3->4 (len 2).
    # Removing any edge: 1->2 -> 1->3->4 (len 2). 2->4 -> 1->2->? no, 1->3->4 (len 2).
    # Wait, if 1->2 and 1->3, 2->4, 3->4. Paths: 1-2-4 (2 edges), 1-3-4 (2 edges).
    # Removing 1->2 -> path 1-3-4 (len 2).
    # Sample output is 2.
    
    # 2. Sample 3: 7 nodes. 1-2-3-4 and 5-6-7. Max path len 3.
    # Removing edge 1-2 -> 1 is dead end, 2-3-4 is len 2. Or 5-6-7 (len 2). 
    # But wait, racer chooses max path initially. If they choose 1-2-3-4, blocked at 1->2.
    # Re-route at 1. No outgoing. Path length 0.
    # Sample output 0.
    
    # 3. Sample 4: 1->2->3->4->5->6 (len 5) or 1->4->5->6 (len 3).
    # Max path is 1-2-3-4-5-6 (len 5).
    # Block 4->5 -> 1-2-3-4... stuck? 
    # Sample output 1. Wait, check logic.
    # 1->2, 1->4, 2->3, 4->5, 5->6.
    # Paths: 1-2-3 (len 2), 1-4-5-6 (len 3).
    # Wait, Sample 4 output is 1.
    # If max path is 1-4-5-6 (len 3). Block 4->5. 
    # Racer at 4. Re-route. No other outgoing. Path ends at 4. Length = edges taken so far = 1 (from 1 to 4).
    # So answer 1.
    
    # Let's construct matrices for these
    test_cases = []
    
    # Case 1: 1-2, 1-3, 2-4, 3-4. Nodes 0,1,2,3 (mapped from 1,2,3,4)
    # Adj 0->1, 0->2, 1->3, 2->3. Max 2. Result 2.
    m1 = [[False]*8 for _ in range(8)]
    m1[0][1] = True
    m1[0][2] = True
    m1[1][3] = True
    m1[2][3] = True
    test_cases.append((m1, 2))

    # Case 3: 1-2-3-4 and 5-6-7. Nodes 0-3, 4-6.
    # 0->1, 1->2, 2->3. 4->5, 5->6.
    # Max path 3. Removing 0->1 -> 1-2-3 (len 2) or 4-5-6 (len 2).
    # Wait, sample output is 0.
    # Ah, sample input: 7 nodes. 1 2, 2 3, 3 4. 5 6, 6 7.
    # Max path length is 3 (edges).
    # If racer chooses path 1-2-3-4. 
    # Block road 1->2. Racer at station 1. No outgoing roads? 
    # Graph: 1->2. 2->3. 3->4. 
    # If 1->2 blocked, at 1, no other edges.
    # Path length = 0 (since no edges traveled from 1).
    # Yes. So 0.
    m3 = [[False]*8 for _ in range(8)]
    m3[0][1] = True
    m3[1][2] = True
    m3[2][3] = True
    m3[4][5] = True
    m3[5][6] = True
    test_cases.append((m3, 0))
    
    # Case 4: 1->2->3, 1->4->5->6.
    # Nodes 0,1,2,3,4,5.
    # 0->1, 1->2, 0->3, 3->4, 4->5.
    # Max path: 0->3->4->5 (len 3).
    # Block 3->4 (edge 4->5 in 0-index? no, 3->4). 
    # At 3, no outgoing. Path length = 1 (edge 0->3).
    # Output 1.
    m4 = [[False]*8 for _ in range(8)]
    m4[0][1] = True
    m4[1][2] = True
    m4[0][3] = True
    m4[3][4] = True
    m4[4][5] = True
    test_cases.append((m4, 1))
    
    # Additional simple case: Linear 1-2-3 (len 2). Block 1->2 -> 0. Block 2->3 -> 1.
    # Max path 2. Min after block = 0 (if we block first edge of only path).
    # Actually, if only one path, blocking first edge gives 0. 
    m5 = [[False]*8 for _ in range(8)]
    m5[0][1] = True
    m5[1][2] = True
    test_cases.append((m5, 0))

    total_tests = len(test_cases)
    passed = 0

    for i, (adj, expected) in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}/{total_tests}")
        
        # Load Matrix
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Send 8 bytes (8x8 matrix flattened)
        # But wait, my prompt said 8 cycles for 8x8. 64 bits. 
        # The input is `input [7:0] adj_matrix_flat`. It says loaded over 8 cycles.
        # That implies 8 bits per cycle. 64 bits total. 8 cycles.
        # But 8x8 matrix is 64 bits. Correct.
        
        for row in range(8):
            val = 0
            for col in range(8):
                if adj[row][col]:
                    val |= (1 << col)
            dut.adj_matrix_flat.value = val
            await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 100:
            dut._log.error(f"Test {i+1} timed out")
            continue
            
        result = int(dut.result.value)
        
        # Allow some flexibility if parallel paths exist vs serialized
        # But our reference logic should match.
        ref = solve_reference(adj)
        
        dut._log.info(f"Result: {result}, Expected: {ref}")
        
        if result == ref:
            passed += 1
        else:
            dut._log.error(f"Test {i+1} Failed! Result {result}, Expected {ref}")

    dut._log.info(f"
{passed}/{total_tests} tests passed")
    assert passed == total_tests
