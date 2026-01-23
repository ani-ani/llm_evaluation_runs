import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def calculate_min_energy_py(edges, alpha, N):
    """Python reference for the adapted small graph problem"""
    M = len(edges)
    min_energy = None
    
    # Iterate all subsets
    for mask in range(1, 1 << M):
        subset = []
        for i in range(M):
            if (mask >> i) & 1:
                subset.append(edges[i])
        
        k = len(subset)
        # Check if it forms a valid cycle (Eulerian subgraph for simple cycles)
        # For a simple cycle (no repeats of vertices except start/end), degree must be 2 for all involved nodes.
        # If self-loop, degree 2. If 2 nodes with 2 edges, degree 2.
        deg = [0] * N
        max_c = 0
        valid_structure = True
        
        for u, v, c in subset:
            deg[u] += 1
            deg[v] += 1 # u and v are distinct. If self-loop, input logic handles (u==v)?
            # Note: Input graph is simple (no self-loops, no multi-edges implied by problem statement? "No two roads have same candies", but could connect same nodes?
            # Usually road connects u, v. If u==v it's a loop. Let's assume u!=v as standard.
            # Wait, if u!=v, then K=2 loop requires two edges between u and v.
            # But problem says "connects two junctions u and v". Could be multiple roads between same pair? Usually yes in graph problems unless specified.
            # Let's stick to standard graph: degree check.
            # If K=1, we need a self-loop (u==v). Since not guaranteed, we ignore K=1 unless present.
            # If K=2 and u!=v, we need two edges between same u,v. 
            # Given constraints of 'distinct c', multi-edges are possible between same nodes.
            if c > max_c: max_c = c
        
        if valid_structure:
            # Check degrees: all non-zero nodes must have degree 2.
            # Also must be connected (simple cycle).
            # We will just check degree constraint and connectivity for simplicity in HW.
            # Connectivity check: BFS on the subset.
            
            # Filter involved nodes
            nodes_involved = [i for i in range(N) if deg[i] > 0]
            if not nodes_involved: continue
            
            # Check degrees
            for d in deg:
                if d > 0 and d != 2:
                    valid_structure = False
                    break
            
            if not valid_structure: continue
            
            # Check connectivity
            visited = set()
            q = [nodes_involved[0]]
            visited.add(nodes_involved[0])
            while q:
                curr = q.pop()
                for u, v, c in subset:
                    if u == curr and v not in visited:
                        visited.add(v)
                        q.append(v)
                    elif v == curr and u not in visited:
                        visited.add(u)
                        q.append(u)
            
            if len(visited) != len(nodes_involved):
                continue
            
            energy = max_c * max_c + alpha * k
            if min_energy is None or energy < min_energy:
                min_energy = energy
                
    return min_energy

@cocotb.test()
async def test_min_energy_cycle(dut):
    """Test min_energy_cycle module"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_edges_count.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await FallingEdge(dut.clk)
    
    # Test Case 1: Triangle (3 nodes, 3 edges) -> Min Energy = c_max^2 + alpha*3
    # Edges: 0-1 (100), 1-2 (200), 2-0 (300). alpha=10
    # Cycle covers all edges: max=300, K=3 -> 90000 + 30 = 90030
    # We have 1 cycle.
    dut.edge_0_u.value = 0
    dut.edge_0_v.value = 1
    dut.edge_0_c.value = 100
    dut.edge_1_u.value = 1
    dut.edge_1_v.value = 2
    dut.edge_1_c.value = 200
    dut.edge_2_u.value = 2
    dut.edge_2_v.value = 0
    dut.edge_2_c.value = 300
    dut.valid_edges_count.value = 3
    dut.alpha.value = 10
    dut.node_count.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (timeout based on state machine cycles for M=3 -> 2^3=8 subsets)
    timeout = 0
    while not dut.valid.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.valid.value:
        res = int(dut.result.value)
        print(f"Test 1 Result: {res}")
        if res != 90030:
            raise TestFailure(f"Expected 90030, got {res}")
    else:
        raise TestFailure("Module timed out on Test 1")
        
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await FallingEdge(dut.clk)

    # Test Case 2: 4 nodes, square + diagonal. 
    # Nodes 0,1,2,3.
    # Edges: 0-1 (1000), 1-2 (10), 2-3 (100), 3-0 (1). alpha=5
    # Small cycle: 0-1-2-3-0 has max=1000, K=4 -> 1000000 + 20 = 1000020
    # Small cycle: 0-1-2 (if connected back)? No.
    # Let's create 2 triangles sharing an edge.
    # 0-1 (10), 1-2 (20), 2-0 (30) -> Cycle 1. Max 30, K=3, Energy 900+15=915
    # 0-1 (10), 1-3 (40), 3-0 (50) -> Cycle 2. Max 50, K=3, Energy 2500+15=2515
    # Total edges 4. 
    # We want to find cycle 1 (915).
    
    dut.edge_0_u.value = 0
    dut.edge_0_v.value = 1
    dut.edge_0_c.value = 10
    dut.edge_1_u.value = 1
    dut.edge_1_v.value = 2
    dut.edge_1_c.value = 20
    dut.edge_2_u.value = 2
    dut.edge_2_v.value = 0
    dut.edge_2_c.value = 30
    dut.edge_3_u.value = 0
    dut.edge_3_v.value = 3
    dut.edge_3_c.value = 50
    dut.edge_4_u.value = 1
    dut.edge_4_v.value = 3
    dut.edge_4_c.value = 40
    dut.valid_edges_count.value = 5
    dut.alpha.value = 5
    dut.node_count.value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.valid.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.valid.value:
        res = int(dut.result.value)
        print(f"Test 2 Result: {res}")
        if res != 915:
            raise TestFailure(f"Expected 915, got {res}")
    else:
        raise TestFailure("Module timed out on Test 2")

    # Test Case 3: No Cycle (Tree)
    # 0-1, 0-2. 
    # Edges: 0-1 (100), 0-2 (200). alpha=10. No cycle.
    # Should output -1 (0xFFFFFFFFFFFFFFFF or similar marker? Problem says 'Poor girl'.
    # In hardware, let's output -1 if no cycle, and handle 'Poor girl' in testbench logic or print.
    # The prompt says "output Poor girl". We will output -1 and testbench checks for it.
    
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await FallingEdge(dut.clk)
    
    dut.edge_0_u.value = 0
    dut.edge_0_v.value = 1
    dut.edge_0_c.value = 100
    dut.edge_1_u.value = 0
    dut.edge_1_v.value = 2
    dut.edge_1_c.value = 200
    dut.valid_edges_count.value = 2
    dut.alpha.value = 10
    dut.node_count.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.valid.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if dut.valid.value:
        res = int(dut.result.value)
        print(f"Test 3 Result: {res}")
        # Check if it represents an error/no-cycle state (e.g., all 1s)
        if res != 0xFFFFFFFFFFFFFFFF:
            raise TestFailure(f"Expected -1 (no cycle), got {res}")
    else:
        raise TestFailure("Module timed out on Test 3")
        
    print("All tests passed")
