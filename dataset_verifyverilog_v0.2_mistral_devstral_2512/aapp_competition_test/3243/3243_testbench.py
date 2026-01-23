import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
def test_network_merger(dut):
    """Test the network merger module with various network topologies."""
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_nodes.value = 0
    dut.k.value = 0
    dut.edge_mask.value = 0
    dut.capacity_mask.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper to pack edges into mask
    def pack_edges(n, edges):
        mask = 0
        for u, v in edges:
            if u < n and v < n:
                # Undirected, store upper triangular to avoid redundancy, 
                # but module expects simple mapping. Let's assume bit (u*8 + v) and (v*8 + u) are valid.
                # We'll set both for simplicity.
                mask |= (1 << (u * 8 + v))
                mask |= (1 << (v * 8 + u))
        return mask

    # Helper to pack capacities
    def pack_caps(caps):
        val = 0
        for i, c in enumerate(caps):
            # Store in 4 bits per node
            val |= (c << (4 * i))
        return val

    # Test Cases
    # 1. Sample 1: 4 nodes, 5 edges (complete graph missing 0-2?), wait input has 0-1,0-3,1-3,1-2,2-3.
    # Graph: 0-1, 0-3, 1-2, 1-3, 2-3. This is a dense graph. 
    # Components = 1. k=2. Should be YES.
    dut._log.info("Running Test 1: Dense 4-node graph")
    dut.num_nodes.value = 4
    dut.k.value = 2
    edges1 = [(0,1), (0,3), (1,3), (1,2), (2,3)]
    dut.edge_mask.value = pack_edges(4, edges1)
    # Capacity 3 for all
    dut.capacity_mask.value = pack_caps([3, 3, 3, 3])
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if not dut.done.value:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 1: Expected YES (1), got {dut.result.value}")
    dut._log.info("Test 1 Passed")
    await RisingEdge(dut.clk)

    # 2. Sample 2: 5 nodes, 4 edges. 
    # Edges: 0-1, 2-3, 3-4, 4-2. 
    # Components: {0,1} and {2,3,4}. Count = 2. 
    # k=4. 
    # We need 1 addition (2-1). 
    # But wait, constraints: capacity is 1,1,2,2,2.
    # Nodes 0 and 1 have capacity 1. They are already connected to 1 peer each. Degree=1. No free sockets.
    # To connect component {0,1} to {2,3,4}, we need to add an edge. 
    # We can't add edge 0-2 because node 0 has no free socket (cap 1, deg 1).
    # So we MUST remove an edge from node 0? No, node 0 has only 1 edge. Can't remove.
    # We MUST remove an edge from node 2? Node 2 has cap 2, deg 2 (edges 2-3, 2-4). 
    # If we remove 2-3, node 2 has free socket. Then add 2-0. Node 0 gets degree 2 > cap 1. Fail.
    # Wait, this Sample 2 output is "yes". 
    # Let's re-read carefully. "An edit is either to remove an existing connection... or to add a new connection".
    # Maybe I can remove a connection from a node to free a socket, but that node MUST remain connected to the graph.
    # If I remove edge 0-1, component {0,1} splits into two. Then I need to connect 0 to {2,3,4} AND 1 to {2,3,4}.
    # This requires 2 additions. 
    # Maybe I remove an edge in the cycle {2,3,4} to free a socket there, then connect {2,3,4} to {0,1}.
    # But {0,1} are saturated. 
    # Ah, capacity 1,1,2,2,2. 
    # Wait, maybe the problem implies we can disconnect a server from one peer and connect to another? 
    # Yes, "edit" covers remove OR add.
    # To connect {0,1} to {2,3,4}, we need at least one edge between them. 
    # Node 0 is saturated. Node 1 is saturated. 
    # So we MUST free a socket on 0 or 1. To free a socket on 0, we must remove edge 0-1.
    # If we remove 0-1, node 0 is free, node 1 is free. 
    # Now we can connect 0 to 2, and 1 to 2? No, node 2 capacity 2. It is connected to 3 and 4. Saturated.
    # So we must free a socket on 2. Remove 2-3. Now 2 has 1 socket free. 3 has 1 free.
    # We have 2 edits so far (remove 0-1, remove 2-3). k=4.
    # We need to connect components. Currently: {0}, {1}, {2,4}, {3}.
    # We need 3 edges to connect 4 components. Total edits = 2 + 3 = 5 > 4. 
    # So maybe the capacities are 1,1,2,2,2. 
    # Wait, maybe I misinterpret "socket". If it has 1 socket, it means it can connect to 1 other server. 
    # The sample output is "yes". 
    # Let's look at the graph again. 
    # Nodes: 0, 1 (cap 1). Nodes: 2, 3, 4 (cap 2).
    # Edges: 0-1 (saturates 0, 1). Cycle 2-3-4-2 (saturates 2, 3, 4).
    # To merge, we need edges between the two sets.
    # We must remove an edge from the cycle to free a socket. e.g. remove 2-3.
    # Now degrees: 0(1), 1(1), 2(1), 3(1), 4(2).
    # We can add edge 0-2. But 0 has degree 1 (max), 2 has degree 1 (max 2). 0-2 is valid. 
    # Now graph: 0-1-? No, 0-1 was NOT removed. 
    # Let's try: Remove 2-3 (Edit 1). Add 0-2 (Edit 2). 
    # Graph: {0, 1}, {0, 2, 4, 3}. Wait, 0 is connected to 1 and 2. Node 0 has 2 connections, cap 1. Invalid.
    # So we MUST remove 0-1.
    # Plan: Remove 0-1 (Edit 1). Remove 2-3 (Edit 2). Add 0-2 (Edit 3). Add 1-3 (Edit 4).
    # Edits = 4. 
    # Check caps: 
    # 0: connected to 2 (deg 1 <= 1). OK.
    # 1: connected to 3 (deg 1 <= 1). OK.
    # 2: connected to 0, 4 (deg 2 <= 2). OK.
    # 3: connected to 1, 4 (deg 2 <= 2). OK.
    # 4: connected to 2, 3 (deg 2 <= 2). OK.
    # Connectivity: 0-2-4-3-1. All connected. 
    # So yes, it works.
    # My simplification logic: "Sum of capacities >= n". 1+1+2+2+2 = 8 >= 5. True.
    # "k >= components - 1". k=4, components=2. 4 >= 1. True.
    # So my simplified logic should output YES.
    
    dut._log.info("Running Test 2: Saturated components")
    dut.num_nodes.value = 5
    dut.k.value = 4
    edges2 = [(0,1), (2,3), (3,4), (4,2)]
    dut.edge_mask.value = pack_edges(5, edges2)
    dut.capacity_mask.value = pack_caps([1, 1, 2, 2, 2])
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if not dut.done.value:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 2: Expected YES (1), got {dut.result.value}")
    dut._log.info("Test 2 Passed")
    await RisingEdge(dut.clk)

    # 3. Sample 3: 3 nodes, 0 edges, k=3. 
    # Components = 3. 
    # Edges needed = 2. k=3. OK.
    # Caps = 1,1,1. Sum = 3 >= 3. OK.
    # Output "no" in sample.
    # Why? 
    # Wait, 3 nodes, cap 1 each. To connect 3 nodes, you need a chain 0-1-2. 
    # Node 1 needs degree 2 (connected to 0 and 2). But cap is 1. 
    # So it's impossible. Sum of capacities = 3. 
    # Actually, in a tree with 3 nodes, the middle node has degree 2, leaves have degree 1.
    # Total degrees = 4. Sum of capacities = 3. 
    # So Sum >= n is NOT sufficient. We need Sum >= 2*(n-1) for a tree? No.
    # For a connected graph, sum of degrees = 2 * num_edges.
    # Min edges to connect n nodes is n-1.
    # So we need sum of capacities >= 2*(n-1).
    # Here n=3, need >= 4. But sum=3. So impossible.
    # My simplified logic "Sum of capacities >= n" was WRONG for this edge case.
    # Correct logic: Sum of capacities >= 2 * (n - 1).
    # But wait, we can remove edges to free sockets? 
    # In this case, no existing edges. We just need to add edges.
    # To connect 3 nodes with cap 1 each, impossible.
    # So my logic needs to be: Sum capacities >= 2*(n-1) OR (special case for small n).
    # However, for the VERILOG task, I need to keep it simple.
    # The prompt asked to check if "k >= components - 1" AND "Sum capacities >= n".
    # The sample 3 shows "Sum capacities >= n" is NOT enough.
    # Let's adjust the Verilog logic in the Prompt to be smarter.
    # Check: Sum capacities >= 2*(num_nodes - 1).
    # IF Sum < 2*(n-1) -> NO.
    # ELSE IF k >= components - 1 -> YES.
    
    dut._log.info("Running Test 3: Insufficient total capacity")
    dut.num_nodes.value = 3
    dut.k.value = 3
    dut.edge_mask.value = 0
    dut.capacity_mask.value = pack_caps([1, 1, 1])
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if not dut.done.value:
        raise TestFailure("Test 3: Timeout waiting for done")
    
    if dut.result.value != 0:
        raise TestFailure(f"Test 3: Expected NO (0), got {dut.result.value}")
    dut._log.info("Test 3 Passed")
    
    dut._log.info("All tests passed!")
