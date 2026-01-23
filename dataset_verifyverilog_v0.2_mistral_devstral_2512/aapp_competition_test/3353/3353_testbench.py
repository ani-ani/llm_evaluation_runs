import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

# Helper to map nodes to 0-based indices (Src=0, Dst=1, Boulders=2..)
def map_node(n):
    if n == -2:
        return 0
    elif n == -1:
        return 1
    else:
        return n + 2

@cocotb.test()
def test_river_crossing_basic(dut):
    """Test the basic case: 2 people, simple graph"""
    # Clock generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.P.value = 0
    dut.num_nodes.value = 0
    dut.num_edges.value = 0
    for i in range(16):
        dut.edges_src[i].value = 0
        dut.edges_dst[i].value = 0
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')

    # Input: P=2, R=4, L=7
    # Edges:
    # -2 0  -> 0 2
    # 0 -1  -> 2 1
    # -2 1  -> 0 3
    # 1 0   -> 3 2
    # 2 1   -> 4 3
    # 2 3   -> 4 5
    # 3 -1  -> 5 1
    
    dut.P.value = 2
    dut.num_nodes.value = 6 # 0,1 + 4 boulders -> 6 total
    dut.num_edges.value = 7
    
    edges = [
        (0, 2), # -2 0
        (2, 1), # 0 -1
        (0, 3), # -2 1
        (3, 2), # 1 0
        (4, 3), # 2 1
        (4, 5), # 2 3
        (5, 1)  # 3 -1
    ]
    
    for i, (src, dst) in enumerate(edges):
        dut.edges_src[i].value = src
        dut.edges_dst[i].value = dst

    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Check results
    # Expected: 2 people cross. 
    # Path 1: 0->2->1 (Length 2)
    # Path 2: 0->3->5->1 (Length 3) OR 0->3->2... but 0->2 is used. 
    # Actually 0->3 (edge 2) -> 5 (edge 5) -> 1 (edge 6). Length 3. Total 5.
    # Wait, sample output is 6. Let's trace sample path.
    # Path 1: 0->2->1 (Edges 0, 1). Length 2. Remaining edges: 2,3,4,5,6
    # Path 2: 0->3->5->1 (Edges 2, 5, 6). Length 3. Total 5.
    # Why sample output 6? 
    # Maybe path 1: 0->3->5->1 (Len 3). Remaining: 0,1,3,4
    # Path 2: 0->2->3... but 0->2 exists, 2->3 exists? No. 2->1 exists (edge 1). 0->2->1 (Len 2). Total 5.
    # Let's re-read sample. 
    # Edges: -2(0) 0(2); 0(2) -1(1); -2(0) 1(3); 1(3) 0(2); 2(4) 1(3); 2(4) 3(5); 3(5) -1(1)
    # Graph:
    # S -2- 0
    # |    |
    # 3    0
    # |    |
    # 1 -2- 3
    # |    |
    # 5 -2- 1
    # |    |
    # T
    # Actually, looking at python solution for this problem, it uses Max Flow.
    # Let's verify flow on sample.
    # S->0 (1), S->1 (1). 
    # 0->T (1). 
    # 1->0 (1). 
    # 2->1 (1). 
    # 2->3 (1). 
    # 3->T (1).
    # Max flow 2. 
    # Paths: 
    # 1. S->0->T. Length 2.
    # 2. S->1->0->T ? Edge 1->0 is used. No. 
    # 2. S->1->2->3->T. Length 4. Total 6.
    # Ah, S->1 is edge 2 (0->3). 1->2 is edge 3 (3->2). 2->3 is edge 5 (4->5). 3->T is edge 6 (5->1).
    # Yes! Path 2 is S->1->2->3->T.
    # My adjacency list was wrong for sample data.
    # Edges:
    # 0 (S) -> 2 (0) - Edge A
    # 2 (0) -> 1 (T) - Edge B
    # 0 (S) -> 3 (1) - Edge C
    # 3 (1) -> 2 (0) - Edge D
    # 4 (2) -> 3 (1) - Edge E
    # 4 (2) -> 5 (3) - Edge F
    # 5 (3) -> 1 (T) - Edge G
    
    # Path 1: S->0->T (A, B). Len 2. 
    # Remove A, B.
    # Path 2: S->1->2->3->T (C, D, E, G?) No. S->1 (C). 1->? D goes to 0. 
    # Wait, edge D is 3->2 (1->0). Edge E is 4->3 (2->1). 
    # S->1 (3). 1->2? No. 
    # S->1->2? No. 
    # S->0 is gone. 
    # S->1 is C. 1->? D is 3->2. So 1->0. 0 is dead end.
    # 1->? No other edges from 1 (node 3) except D (to 0).
    # What about S->0? Used.
    # Is there another flow?
    # Let's check the Python output 6.
    # Maybe I missed an edge in adjacency.
    # Edges:
    # -2 0 -> S 0
    # 0 -1 -> 0 T
    # -2 1 -> S 1
    # 1 0 -> 1 0
    # 2 1 -> 2 1
    # 2 3 -> 2 3
    # 3 -1 -> 3 T
    # Nodes: S, T, 0, 1, 2, 3.
    # S->0, S->1
    # 0->T, 0<-1
    # 1->0
    # 2->1, 2->3
    # 3->T
    
    # Path 1: S->0->T (Len 2).
    # Path 2: S->1->0->T? No, 0->T used.
    # Path 2: S->1->0->... dead.
    # Path 2: S->1->0->... no.
    # Wait, maybe Path 1 is S->1->2->3->T (Len 4).
    # S->1, 1->2, 2->3, 3->T. 
    # Path 2: S->0->T (Len 2).
    # Total 6. 
    # Yes, this matches 6.
    
    assert dut.total_time.value == 6, f"Expected 6, got {dut.total_time.value}"
    assert dut.possible.value == 1, "Should be possible"
    assert dut.people_left.value == 0, "No one left"
    print("Test 1 Passed: Time=6")

@cocotb.test()
def test_river_crossing_impossible(dut):
    """Test case where not everyone can cross"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')

    # Input 2: 3 people, 2 boulders, 5 logs
    # -2 0 -> 0 2
    # -2 1 -> 0 3
    # 0 1  -> 2 3
    # 1 -1 -> 3 1
    # 0 -1 -> 2 1
    
    dut.P.value = 3
    dut.num_nodes.value = 4 # S, T, 0, 1
    dut.num_edges.value = 5
    
    edges = [
        (0, 2),
        (0, 3),
        (2, 3),
        (3, 1),
        (2, 1)
    ]
    
    for i, (src, dst) in enumerate(edges):
        dut.edges_src[i].value = src
        dut.edges_dst[i].value = dst
        
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
        
    # Expected: Max flow is 2. (S->0->T, S->1->T). 
    # Paths: S->0->T (Len 2), S->1->T (Len 2). Total 4.
    # People crossed: 2. Left: 1.
    
    # Wait, sample output says "1 people left behind".
    # Sample input P=3.
    # My logic: 2 crossed, 3-2=1 left. Correct.
    # But the output format is just "1", not "1 people left behind"? 
    # The problem description says: "print n people left behind".
    # The sample output for case 2 is "1 people left behind".
    # However, the JSON structure for test outputs provided in the prompt shows "1 people left behind
".
    # The module output `people_left` should be 1.
    
    assert dut.people_left.value == 1, f"Expected 1 left, got {dut.people_left.value}"
    assert dut.possible.value == 0, "Should be impossible"
    assert dut.total_time.value == 4, f"Expected 4, got {dut.total_time.value}"
    print("Test 2 Passed: Left=1")
