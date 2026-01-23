import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

MOD = 11092019

def get_expected_result(nodes):
    """
    nodes: list of tuples (label, parent_index)
    Returns (max_len, count)
    """
    n = len(nodes)
    labels = [node[0] for node in nodes]
    parents = [node[1] for node in nodes]
    
    # DP arrays
    dp_len = [0] * n
    dp_cnt = [0] * n
    
    # Process nodes in order (assume input order matches index 0..n-1)
    for i in range(n):
        label = labels[i]
        parent = parents[i]
        
        # Initialize for this node (path starting at itself)
        curr_len = 1
        curr_cnt = 1
        
        # Check ancestors
        # We need to trace back from parent to root
        curr_parent = parent
        ancestors = []
        # Only valid if parent != 0 or i == 0. 
        # In the problem, root has no parent. In input, root's parent line is skipped.
        # In our simplified testbench, we'll assume node 0 is root (parent 0).
        # For node i > 0, parent is valid.
        
        if i > 0:
            # Trace ancestors from parent
            p = curr_parent
            while p != 0 or (p == 0 and nodes[p][1] == 0): # Simple check to stop at root
                 # Check if p is a valid ancestor to consider
                 # Actually, we just need to walk up the tree
                 # But our 'parents' array has index of parent.
                 # If p==0, it's root. We check it. Then we look at its parent.
                 # If root's parent is 0, we stop.
                 
                 # Wait, the loop needs to traverse ALL ancestors.
                 # Path: i -> parent -> parent's parent -> ... -> root (0)
                 
                 # Let's trace the chain
                 pass
        
        # Correct ancestor traversal
        current = i
        if i > 0:
            current = parent
            while True:
                anc_label = labels[current]
                anc_len = dp_len[current]
                anc_cnt = dp_cnt[current]
                
                if anc_label <= label:
                    if anc_len + 1 > curr_len:
                        curr_len = anc_len + 1
                        curr_cnt = anc_cnt
                    elif anc_len + 1 == curr_len:
                        curr_cnt = (curr_cnt + anc_cnt) % MOD
                
                if current == 0:
                    break
                current = parents[current]
        
        dp_len[i] = curr_len
        dp_cnt[i] = curr_cnt

    max_len = max(dp_len) if n > 0 else 0
    count = 0
    for i in range(n):
        if dp_len[i] == max_len:
            count = (count + dp_cnt[i]) % MOD
            
    return max_len, count

@cocotb.test()
async def test_tree_lis_solver(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.node_label.value = 0
    dut.node_parent.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: 5 nodes, all labels 3, chain 1-2-3-4-5
    # Labels: [3,3,3,3,3], Parents: [0,1,2,3,4] (indices 1-based in input, 0-based here)
    # Wait, input says: "line i gives the parent p_i < i".
    # So v_1 is root. v_2 parent is 1. v_3 parent is 2. etc.
    # In 0-based indexing: v[0] root. v[1] parent 0. v[2] parent 1. v[3] parent 2. v[4] parent 3.
    
    nodes1 = [(3,0), (3,0), (3,1), (3,2), (3,3)] # Wait, input "1
2
3
4" means: 
    # v2 parent 1, v3 parent 2, v4 parent 3, v5 parent 4.
    # Indices: 1->0, 2->1, 3->2, 4->3.
    # So: v0: root, v1: parent 0, v2: parent 1, v3: parent 2, v4: parent 3.
    nodes1 = [(3,0), (3,0), (3,1), (3,2), (3,3)]
    
    dut._log.info("Test Case 1: Chain of 5")
    for i, (label, parent) in enumerate(nodes1):
        dut.valid_in.value = 1
        dut.node_label.value = label
        dut.node_parent.value = parent
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        # Wait for processing if needed, or just feed data
        # Our design should process internally.
        # We assume the design accumulates results.
        
    # Wait for completion
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted")
        
    exp_len, exp_cnt = get_expected_result(nodes1)
    dut._log.info(f"Expected: L={exp_len}, M={exp_cnt}")
    dut._log.info(f"Got: L={int(dut.max_length)}, M={int(dut.path_count)}")
    
    if int(dut.max_length) != exp_len or int(dut.path_count) != exp_cnt:
        raise TestFailure(f"Test 1 Failed: Expected {exp_len} {exp_cnt}, Got {int(dut.max_length)} {int(dut.path_count)}")

    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: 5 nodes, decreasing labels
    nodes2 = [(4,0), (3,0), (2,1), (1,2), (0,3)]
    dut._log.info("Test Case 2: Decreasing")
    for i, (label, parent) in enumerate(nodes2):
        dut.valid_in.value = 1
        dut.node_label.value = label
        dut.node_parent.value = parent
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0

    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    exp_len, exp_cnt = get_expected_result(nodes2)
    if int(dut.max_length) != exp_len or int(dut.path_count) != exp_cnt:
        raise TestFailure(f"Test 2 Failed: Expected {exp_len} {exp_cnt}, Got {int(dut.max_length)} {int(dut.path_count)}")

    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 3: 4 nodes
    nodes3 = [(1,0), (5,0), (3,1), (6,2)]
    dut._log.info("Test Case 3: Branching")
    for i, (label, parent) in enumerate(nodes3):
        dut.valid_in.value = 1
        dut.node_label.value = label
        dut.node_parent.value = parent
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0

    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break

    exp_len, exp_cnt = get_expected_result(nodes3)
    if int(dut.max_length) != exp_len or int(dut.path_count) != exp_cnt:
        raise TestFailure(f"Test 3 Failed: Expected {exp_len} {exp_cnt}, Got {int(dut.max_length)} {int(dut.path_count)}")

    # Test Case 4: 6 nodes, star
    nodes4 = [(1,0), (2,0), (3,0), (4,0), (5,0), (6,0)]
    dut._log.info("Test Case 4: Star")
    for i, (label, parent) in enumerate(nodes4):
        dut.valid_in.value = 1
        dut.node_label.value = label
        dut.node_parent.value = parent
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0

    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break

    exp_len, exp_cnt = get_expected_result(nodes4)
    if int(dut.max_length) != exp_len or int(dut.path_count) != exp_cnt:
        raise TestFailure(f"Test 4 Failed: Expected {exp_len} {exp_cnt}, Got {int(dut.max_length)} {int(dut.path_count)}")

    dut._log.info("All tests passed!")