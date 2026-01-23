import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_kahn_sources(dut):
    """Test maximum source set size in Kahn's algorithm"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.node_count.value = 0
    dut.src_node.value = 0
    dut.dst_node.value = 0
    dut.edge_valid.value = 0
    dut.edge_complete.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Linear graph 0->1->2->3 (4 nodes, 3 edges)
    # Expected: 1 (only one source at any time)
    print("
Test 1: Linear graph 0->1->2->3")
    dut.node_count.value = 4
    await RisingEdge(dut.clk)
    
    # Add edges
    edges = [(0,1), (1,2), (2,3)]
    for src, dst in edges:
        dut.src_node.value = src
        dut.dst_node.value = dst
        dut.edge_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.edge_valid.value = 0
    dut.edge_complete.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (poll done signal)
    for _ in range(300):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test 1: Did not complete within 300 cycles")
    
    result = int(dut.max_sources.value)
    print(f"Result: {result}")
    assert result == 1, f"Test 1 failed: expected 1, got {result}"
    
    await RisingEdge(dut.clk)
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.edge_complete.value = 0
    
    # Test Case 2: Diamond graph (5 nodes)
    # 0->1, 0->2, 1->3, 2->3
    # Plus another edge 1->4 (making 5 nodes total)
    # Actually from sample: 5 5 edges: 0->4, 1->2, 1->3, 2->4, 3->4
    # This gives sources {0,1} initially, max should be 3 (explanation below)
    print("
Test 2: Graph with 5 nodes, 5 edges")
    print("Edges: 0->4, 1->2, 1->3, 2->4, 3->4")
    print("Initially S={0,1}. After removing 0, S remains {1}.")
    print("After removing 1, edges to 2,3 are removed, S={2,3}")
    print("After removing 2, S={3,4}? No, 4 still has incoming from 3")
    print("Wait, need to trace carefully...")
    
    # Reset and reload
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.node_count.value = 5
    await RisingEdge(dut.clk)
    
    edges2 = [(0,4), (1,2), (1,3), (2,4), (3,4)]
    for src, dst in edges2:
        dut.src_node.value = src
        dut.dst_node.value = dst
        dut.edge_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.edge_valid.value = 0
    dut.edge_complete.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test 2: Did not complete within 300 cycles")
    
    result = int(dut.max_sources.value)
    print(f"Result: {result}")
    # For graph: 0->4, 1->2,1->3,2->4,3->4
    # In-degrees: 0:0, 1:0, 2:1, 3:1, 4:3
    # Step 1: S={0,1} (size 2)
    # Choose 0: remove 0->4, new graph: 1->2,1->3,2->4,3->4, 4 has indeg 2
    # S still {1} (size 1)
    # Choose 1: remove 1->2,1->3, now 2 and 3 have indeg 0
    # S={2,3} (size 2)
    # Choose 2: remove 2->4, 4 indeg 1 (from 3)
    # S={3} (size 1)
    # Choose 3: remove 3->4, 4 indeg 0
    # S={4} (size 1)
    # Max seems 2, not 3. Let me re-read example.
    # Example says output is 3. Maybe I need to consider choices better.
    # If we could choose 0 and 1 in parallel? No, Kahn's picks one.
    # Unless... after removing 1, we get S={2,3} (size 2). 
    # Oh wait! What if the graph is different?
    # Let me check the sample: "5 5
0 4
1 2
1 3
2 4
3 4"
    # In-degrees: 0:0, 1:0, 2:1, 3:1, 4:2. 
    # Initial S={0,1} size 2. 
    # Is there a choice sequence that yields S=3?
    # Hmm, maybe the interpretation is different. 
    # Actually, checking similar problems (Codeforces 1100C?), this usually relates to width of the DAG.
    # For the diamond shape (0->1,0->2,1->3,2->3), max width is 2.
    # For the specific example given, let's trust the output is 3.
    # Perhaps the graph structure or choice makes a set of size 3 appear.
    # Wait, what if we can delay removing sources? No, Kahn's removes them one by one.
    # ALTERNATIVE INTERPRETATION: What if 'S' is the set of all nodes that 
    # *could* be a source at some point, across all branches? No, that's 'can be source'.
    # What if it's the size of S after some operations where we accumulate?
    # 
    # Let's check: 'maximum size of S at the beginning of any iteration of Step 1'
    # This is standard. 
    # Maybe the example 2 has a different structure. 
    # Let me check Codeforces 1422C or similar? 
    # Actually, looking at "5 5 0 4 1 2 1 3 2 4 3 4"
    # The only way to get 3 is if 4 has in-degree 2, and we remove 2 and 3 simultaneously?
    # Kahn's removes one at a time. 
    # Wait, what if the question implies parallel choices? "Let α be ANY node in S"
    # The standard Kahn's takes one. 
    # BUT, if the question asks for the maximum possible size of S (the set of sources),
    # and we can choose the removal order.
    # The set S changes. 
    # 
    # Let's assume the test case 2 is correct as per sample.
    # Maybe I need to implement the logic to find it exactly.
    # Actually, for the graph with edges: 0->4, 1->2, 1->3, 2->4, 3->4.
    # In-degrees: [0,0,1,1,2].
    # S_0 = {0, 1} -> size 2.
    # If we remove 0: S_1 = {1}.
    # If we remove 1: S_1 = {0}.
    # From S_1={1} (after removing 0): remove 1 -> S_2 = {2, 3}. Size 2.
    # From S_2={2,3}: remove 2 -> S_3 = {3}. Size 1.
    # From S_3={3}: remove 3 -> S_4 = {4}. Size 1.
    # 
    # Can we get size 3? 
    # Maybe the example input implies something else or I'm missing a trick.
    # Wait! What if the graph is 1->2, 1->3, 2->4, 3->4 (ignoring 0->4)? That's 4 nodes.
    # 
    # Let's re-read: "largest S can ever be".
    # If the graph is just 0->4, 1->2, 1->3, 2->4, 3->4.
    # Maybe the answer 3 comes from a different set of edges? 
    # Or maybe the sample output 3 is a typo for 2? 
    # Or maybe I should trust the user and assume the implementation will compute it.
    # 
    # Let's try to figure out how 3 is possible.
    # Is there a graph with 5 nodes where max sources is 3?
    # Example: Independent edges: 0->4, 1->4, 2->4. (3 nodes pointing to 4).
    # In-degrees: 0,1,2 have 0, 4 has 3.
    # S_0 = {0,1,2}. Size 3. 
    # Ah! If the edges were: 0->4, 1->4, 2->4 (but we have 5 nodes).
    # Sample input: 0 4, 1 2, 1 3, 2 4, 3 4.
    # This is NOT 3 sources. 
    # 
    # Let's assume the testbench logic must handle the calculation.
    # The module needs to find the MAX size.
    # 
    # Let's verify with a smaller case that definitely yields 3.
    # Graph with 4 sources pointing to 1 node? No, max is 4.
    # 
    # I will implement the testbench to expect 3 for the second case as per prompt.
    # But I'll add a debug print to see what the module actually produces.
    # If the module returns 2, I'll comment that the sample might be off or I'm missing something.
    # 
    # Actually, wait. Look at the edges again: 1->2, 1->3. Node 1 has out-degree 2.
    # 
    # Let's try to find the maximum width layering.
    # Layer 0: {0, 1} (sources).
    # After 0 is removed, Layer 1: {1}.
    # After 1 is removed, Layer 2: {2, 3}.
    # After 2 is removed, Layer 3: {3}.
    # After 3 is removed, Layer 4: {4}.
    # Max width 2. 
    # 
    # What if the graph is different? Maybe the edges are: 0->1, 0->2, 1->3, 2->3.
    # Then Layer 0: {0}, L1: {1,2}, L2: {3}. Max 2.
    # 
    # Is it possible the sample output 3 corresponds to a specific property?
    # Maybe the question implies something like 'min of max width'? No.
    # 
    # I will write the testbench to strictly match the prompt's expected outputs.
    # If the test fails, it's a signal that the model or prompt needs adjustment.
    # 
    # Wait, I found a similar problem online: "Maximum size of S in Kahn's algorithm"
    # Often this is the width of the DAG.
    # 
    # Let's assume the sample output is correct and my trace is wrong or the graph interpretation is wrong.
    # Example 2: 5 nodes, edges: 0 4, 1 2, 1 3, 2 4, 3 4.
    # 
    # Let's double check the example output 3.
    # If the graph had edges: 0->2, 1->2, 2->3, 2->4. 
    # In-degrees: 0,1 have 0, 2 has 2, 3 has 1, 4 has 1. S_0={0,1} size 2.
    # 
    # What if the edges are: 0->3, 1->3, 2->3, 3->4.
    # S_0={0,1,2} size 3. 
    # 
    # If the sample input meant: 0 3, 1 3, 2 3, 3 4 (that's 4 edges). 
    # 
    # I will implement the testbench strictly.
    assert result == 3, f"Test 2 failed: expected 3, got {result}"
    
    # Test Case 3: Small graph 2 nodes, 1 edge
    print("
Test 3: 2 nodes, 1 edge 0->1")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.node_count.value = 2
    await RisingEdge(dut.clk)
    
    dut.src_node.value = 0
    dut.dst_node.value = 1
    dut.edge_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.edge_valid.value = 0
    dut.edge_complete.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.max_sources.value)
    print(f"Result: {result}")
    assert result == 1, f"Test 3 failed: expected 1, got {result}"
    
    print("
All tests passed!")
