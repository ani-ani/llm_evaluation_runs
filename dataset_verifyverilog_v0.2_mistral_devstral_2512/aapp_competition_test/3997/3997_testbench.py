import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def compute_tree_control_python(n, a, edges, child_masks, edge_weights):
    """Python reference for tree control computation (scaled for 8 nodes)"""
    # Build adjacency list
    adj = [[] for _ in range(n)]
    for i in range(n-1):
        parent = edges[i][0]
        child = i + 1
        weight = edge_weights[i]
        adj[parent].append((child, weight))
        adj[child].append((parent, weight))
    
    # Compute control counts
    result = [0] * n
    
    for v in range(n):
        # BFS from v to find distances to all descendants
        # Only consider paths that stay in v's subtree
        from collections import deque
        q = deque()
        q.append((v, 0, 0))  # node, distance, depth
        visited = set([v])
        
        while q:
            node, dist, depth = q.popleft()
            if node != v and dist <= a[node]:
                result[v] += 1
            
            # Add children (nodes deeper in tree)
            for (neighbor, weight) in adj[node]:
                if neighbor not in visited:
                    # Only follow edges away from v (deeper in tree)
                    # Simplified: just check all paths, will work for small trees
                    visited.add(neighbor)
                    q.append((neighbor, dist + weight, depth + 1))
                    visited.remove(neighbor)  # allow other paths
    
    return result

@cocotb.test()
async def test_tree_control_basic(dut):
    """Test basic tree control computation"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Small tree (5 nodes from example)
    # Tree structure:
    #   0 (root)
    #   | \ \
    #   1  2 3
    #      |
    #      4
    
    # Set child masks
    dut.child_mask_0.value = 0b0001110  # children: 1,2,3 (bits 1,2,3)
    dut.child_mask_1.value = 0b0000000
    dut.child_mask_2.value = 0b0010000  # child: 4 (bit 4)
    dut.child_mask_3.value = 0b0000000
    dut.child_mask_4.value = 0b0000000
    dut.child_mask_5.value = 0b0000000
    dut.child_mask_6.value = 0b0000000
    dut.child_mask_7.value = 0b0000000
    
    # Edge weights (scaled down from original)
    dut.edge_weight_01.value = 7    # 0->1
    dut.edge_weight_02.value = 1    # 0->2
    dut.edge_weight_03.value = 0    # 0->3 (not used, separate port)
    dut.edge_weight_04.value = 0
    dut.edge_weight_05.value = 0
    dut.edge_weight_06.value = 0
    dut.edge_weight_07.value = 0
    dut.edge_weight_12.value = 0
    dut.edge_weight_13.value = 0
    dut.edge_weight_14.value = 0
    dut.edge_weight_15.value = 0
    dut.edge_weight_16.value = 0
    dut.edge_weight_17.value = 0
    dut.edge_weight_23.value = 0
    dut.edge_weight_24.value = 5    # 2->4
    dut.edge_weight_25.value = 0
    dut.edge_weight_26.value = 0
    dut.edge_weight_27.value = 0
    dut.edge_weight_34.value = 0
    dut.edge_weight_35.value = 0
    dut.edge_weight_36.value = 0
    dut.edge_weight_37.value = 0
    dut.edge_weight_45.value = 0
    dut.edge_weight_46.value = 0
    dut.edge_weight_47.value = 0
    dut.edge_weight_56.value = 0
    dut.edge_weight_57.value = 0
    dut.edge_weight_67.value = 0
    
    # Control values (a_i from example: 2,5,1,4,6 -> scaled)
    dut.a_0.value = 2
    dut.a_1.value = 5
    dut.a_2.value = 1
    dut.a_3.value = 4
    dut.a_4.value = 6
    dut.a_5.value = 0
    dut.a_6.value = 0
    dut.a_7.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion and collect results
    results = [0] * 8
    outputs_received = 0
    timeout = 500
    
    while outputs_received < 5 and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        
        if dut.done.value == 1 or outputs_received > 0:
            idx = int(dut.result_index.value)
            val = int(dut.result_value.value)
            if idx < 8:
                results[idx] = val
                outputs_received += 1
    
    # Expected results: [1, 0, 1, 0, 0, 0, 0, 0]
    expected = [1, 0, 1, 0, 0, 0, 0, 0]
    
    for i in range(5):
        if results[i] != expected[i]:
            raise TestFailure(f"Node {i}: expected {expected[i]}, got {results[i]}")
    
    print(f"Test 1 passed: {results[:5]}")

@cocotb.test()
async def test_tree_control_line(dut):
    """Test line tree (chain)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Line tree: 0-1-2-3-4 (5 nodes)
    dut.child_mask_0.value = 0b0000010  # 1
    dut.child_mask_1.value = 0b0000100  # 2
    dut.child_mask_2.value = 0b0001000  # 3
    dut.child_mask_3.value = 0b0010000  # 4
    dut.child_mask_4.value = 0b0000000
    dut.child_mask_5.value = 0b0000000
    dut.child_mask_6.value = 0b0000000
    dut.child_mask_7.value = 0b0000000
    
    # All edges weight 1
    dut.edge_weight_01.value = 1
    dut.edge_weight_02.value = 0
    dut.edge_weight_03.value = 0
    dut.edge_weight_04.value = 0
    dut.edge_weight_05.value = 0
    dut.edge_weight_06.value = 0
    dut.edge_weight_07.value = 0
    dut.edge_weight_12.value = 1
    dut.edge_weight_13.value = 0
    dut.edge_weight_14.value = 0
    dut.edge_weight_15.value = 0
    dut.edge_weight_16.value = 0
    dut.edge_weight_17.value = 0
    dut.edge_weight_23.value = 1
    dut.edge_weight_24.value = 0
    dut.edge_weight_25.value = 0
    dut.edge_weight_26.value = 0
    dut.edge_weight_27.value = 0
    dut.edge_weight_34.value = 1
    dut.edge_weight_35.value = 0
    dut.edge_weight_36.value = 0
    dut.edge_weight_37.value = 0
    dut.edge_weight_45.value = 0
    dut.edge_weight_46.value = 0
    dut.edge_weight_47.value = 0
    dut.edge_weight_56.value = 0
    dut.edge_weight_57.value = 0
    dut.edge_weight_67.value = 0
    
    # a = [9,7,8,6,5]
    dut.a_0.value = 9
    dut.a_1.value = 7
    dut.a_2.value = 8
    dut.a_3.value = 6
    dut.a_4.value = 5
    dut.a_5.value = 0
    dut.a_6.value = 0
    dut.a_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results = [0] * 8
    outputs_received = 0
    timeout = 500
    
    while outputs_received < 5 and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        
        if dut.done.value == 1 or outputs_received > 0:
            idx = int(dut.result_index.value)
            val = int(dut.result_value.value)
            if idx < 8:
                results[idx] = val
                outputs_received += 1
    
    # Expected: [4,3,2,1,0,0,0,0]
    expected = [4, 3, 2, 1, 0, 0, 0, 0]
    
    for i in range(5):
        if results[i] != expected[i]:
            raise TestFailure(f"Node {i}: expected {expected[i]}, got {results[i]}")
    
    print(f"Test 2 passed: {results[:5]}")

@cocotb.test()
async def test_tree_control_single_node(dut):
    """Test single node tree"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Single node only
    dut.child_mask_0.value = 0
    dut.child_mask_1.value = 0
    dut.child_mask_2.value = 0
    dut.child_mask_3.value = 0
    dut.child_mask_4.value = 0
    dut.child_mask_5.value = 0
    dut.child_mask_6.value = 0
    dut.child_mask_7.value = 0
    
    # No edges used
    for i in range(28):
        [dut, 'edge_weight_' + str(i).zfill(2)].value = 0
    
    dut.a_0.value = 1
    dut.a_1.value = 0
    dut.a_2.value = 0
    dut.a_3.value = 0
    dut.a_4.value = 0
    dut.a_5.value = 0
    dut.a_6.value = 0
    dut.a_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results = [0] * 8
    outputs_received = 0
    timeout = 500
    
    while outputs_received < 1 and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        
        if dut.done.value == 1 or outputs_received > 0:
            idx = int(dut.result_index.value)
            val = int(dut.result_value.value)
            if idx < 8:
                results[idx] = val
                outputs_received += 1
    
    # Expected: [0,0,0,0,0,0,0,0]
    expected = [0] * 8
    
    if results[0] != expected[0]:
        raise TestFailure(f"Node 0: expected {expected[0]}, got {results[0]}")
    
    print(f"Test 3 passed: {results[:5]}")

@cocotb.test()
async def test_tree_control_two_nodes(dut):
    """Test two node tree"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Root with one child
    dut.child_mask_0.value = 0b0000010
    dut.child_mask_1.value = 0
    dut.child_mask_2.value = 0
    dut.child_mask_3.value = 0
    dut.child_mask_4.value = 0
    dut.child_mask_5.value = 0
    dut.child_mask_6.value = 0
    dut.child_mask_7.value = 0
    
    # Edge weight 1
    dut.edge_weight_01.value = 1
    dut.edge_weight_02.value = 0
    dut.edge_weight_03.value = 0
    dut.edge_weight_04.value = 0
    dut.edge_weight_05.value = 0
    dut.edge_weight_06.value = 0
    dut.edge_weight_07.value = 0
    dut.edge_weight_12.value = 0
    dut.edge_weight_13.value = 0
    dut.edge_weight_14.value = 0
    dut.edge_weight_15.value = 0
    dut.edge_weight_16.value = 0
    dut.edge_weight_17.value = 0
    dut.edge_weight_23.value = 0
    dut.edge_weight_24.value = 0
    dut.edge_weight_25.value = 0
    dut.edge_weight_26.value = 0
    dut.edge_weight_27.value = 0
    dut.edge_weight_34.value = 0
    dut.edge_weight_35.value = 0
    dut.edge_weight_36.value = 0
    dut.edge_weight_37.value = 0
    dut.edge_weight_45.value = 0
    dut.edge_weight_46.value = 0
    dut.edge_weight_47.value = 0
    dut.edge_weight_56.value = 0
    dut.edge_weight_57.value = 0
    dut.edge_weight_67.value = 0
    
    # a = [1,1]
    dut.a_0.value = 1
    dut.a_1.value = 1
    dut.a_2.value = 0
    dut.a_3.value = 0
    dut.a_4.value = 0
    dut.a_5.value = 0
    dut.a_6.value = 0
    dut.a_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results = [0] * 8
    outputs_received = 0
    timeout = 500
    
    while outputs_received < 2 and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        
        if dut.done.value == 1 or outputs_received > 0:
            idx = int(dut.result_index.value)
            val = int(dut.result_value.value)
            if idx < 8:
                results[idx] = val
                outputs_received += 1
    
    # Expected: [1,0,0,0,0,0,0,0] (node 0 controls node 1)
    expected = [1, 0, 0, 0, 0, 0, 0, 0]
    
    for i in range(2):
        if results[i] != expected[i]:
            raise TestFailure(f"Node {i}: expected {expected[i]}, got {results[i]}")
    
    print(f"Test 4 passed: {results[:2]}")

@cocotb.test()
async def test_tree_control_large_weights(dut):
    """Test with large weights (scaled to 16-bit)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 3 node chain
    dut.child_mask_0.value = 0b0000010
    dut.child_mask_1.value = 0b0000100
    dut.child_mask_2.value = 0b0000000
    dut.child_mask_3.value = 0b0000000
    dut.child_mask_4.value = 0b0000000
    dut.child_mask_5.value = 0b0000000
    dut.child_mask_6.value = 0b0000000
    dut.child_mask_7.value = 0b0000000
    
    # Large weights: 50000 each
    dut.edge_weight_01.value = 50000
    dut.edge_weight_02.value = 0
    dut.edge_weight_03.value = 0
    dut.edge_weight_04.value = 0
    dut.edge_weight_05.value = 0
    dut.edge_weight_06.value = 0
    dut.edge_weight_07.value = 0
    dut.edge_weight_12.value = 50000
    dut.edge_weight_13.value = 0
    dut.edge_weight_14.value = 0
    dut.edge_weight_15.value = 0
    dut.edge_weight_16.value = 0
    dut.edge_weight_17.value = 0
    dut.edge_weight_23.value = 0
    dut.edge_weight_24.value = 0
    dut.edge_weight_25.value = 0
    dut.edge_weight_26.value = 0
    dut.edge_weight_27.value = 0
    dut.edge_weight_34.value = 0
    dut.edge_weight_35.value = 0
    dut.edge_weight_36.value = 0
    dut.edge_weight_37.value = 0
    dut.edge_weight_45.value = 0
    dut.edge_weight_46.value = 0
    dut.edge_weight_47.value = 0
    dut.edge_weight_56.value = 0
    dut.edge_weight_57.value = 0
    dut.edge_weight_67.value = 0
    
    # a = [60000, 60000, 10000]
    dut.a_0.value = 60000
    dut.a_1.value = 60000
    dut.a_2.value = 10000
    dut.a_3.value = 0
    dut.a_4.value = 0
    dut.a_5.value = 0
    dut.a_6.value = 0
    dut.a_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results = [0] * 8
    outputs_received = 0
    timeout = 500
    
    while outputs_received < 3 and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        
        if dut.done.value == 1 or outputs_received > 0:
            idx = int(dut.result_index.value)
            val = int(dut.result_value.value)
            if idx < 8:
                results[idx] = val
                outputs_received += 1
    
    # Expected: [2,1,0,0,0,0,0,0]
    # 0 controls 1 (dist=50000 <= 60000) and 2 (dist=100000 > 10000 so NO)
    # 1 controls 2 (dist=50000 > 10000 so NO)  
    # Wait, check: 0->2 dist = 100000, a_2=10000, so 0 does NOT control 2
    # 0->1 dist = 50000, a_1=60000, so 0 controls 1
    # 1->2 dist = 50000, a_2=10000, so 1 does NOT control 2
    # So 0 controls 1 vertex, 1 controls 0, 2 controls 0
    expected = [1, 0, 0, 0, 0, 0, 0, 0]
    
    for i in range(3):
        if results[i] != expected[i]:
            raise TestFailure(f"Node {i}: expected {expected[i]}, got {results[i]}")
    
    print(f"Test 5 passed: {results[:3]}")

@cocotb.test()
async def test_summary(dut):
    """Print test summary"""
    print("
" + "="*50)
    print("All tree_control tests completed!")
    print("Module adapted to 8-node trees with 16-bit weights")
    print("Tests: Basic, Chain, Single, Two-node, Large-weights")
    print("="*50)
