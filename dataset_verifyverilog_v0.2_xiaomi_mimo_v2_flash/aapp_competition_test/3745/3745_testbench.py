import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_graph_validator(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_edges.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: N=2, Edge 1-2 (Should be valid: aa, ab, ba, bb, bc, cb, cc)
    # Adjacency matrix logic: 2 nodes connected. Can be 'a'-'a', 'a'-'b', 'b'-'c', etc.
    # Let's force the algorithm. We need a non-edge to start 'a'-'c' logic.
    # With 1 edge on 2 nodes, they ARE connected. So the non-edge check fails.
    # The code should output 'aa' (complete graph).
    print("Test 1: N=2, M=1, Edge 1-2")
    dut.num_edges.value = 1
    dut.edge_u[0].value = 0 # Vertex 0 (1 in 1-based)
    dut.edge_v[0].value = 1 # Vertex 1 (2 in 1-based)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (assuming done signal exists or wait sufficient time)
    # For simplicity, wait fixed cycles
    for _ in range(50):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            break
    
    if dut.valid.value != 1:
        raise TestFailure("Test 1 failed: valid should be 1")
    res = bytes([int(dut.result_string[i].value) for i in range(2)]).decode('ascii')
    print(f"Result: {res}")
    # Expected 'aa'
    if res != 'aa':
        raise TestFailure(f"Test 1 failed: Expected 'aa', got {res}")

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: N=4, M=3, Edges 1-2, 1-3, 1-4 (Star graph)
    # 1 connects to 2, 3, 4. 2, 3, 4 do not connect to each other.
    # This means 1 is 'b'. 2, 3, 4 must be 'a' or 'c'. But they are not connected to each other.
    # If they are 'a' and 'c', they shouldn't connect. Correct.
    # So 2, 3, 4 can be 'a', 'c', 'a' for example. But wait, check logic.
    # 1 is 'b' (connects to both 'a' and 'c').
    # 2, 3, 4 are not connected to each other. So they must be 'a' and 'c' (or all same, but then they'd connect).
    # So 2, 3, 4 must be a mix of 'a' and 'c'. But there are 3 nodes. Only 2 letters ('a', 'c').
    # By pigeonhole, two of them must be same. If same, they should connect. But they don't.
    # So this graph is impossible. Expected: No.
    print("
Test 2: N=4, M=3, Edges 1-2, 1-3, 1-4")
    dut.num_edges.value = 3
    dut.edge_u[0].value = 0; dut.edge_v[0].value = 1 # 1-2
    dut.edge_u[1].value = 0; dut.edge_v[1].value = 2 # 1-3
    dut.edge_u[2].value = 0; dut.edge_v[2].value = 3 # 1-4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1 or dut.valid.value == 0: # Check if settled
             # We need to wait for 'DONE' state. Let's assume valid stays stable.
             pass
    
    # The algorithm in the prompt checks validity. It should detect the conflict.
    # However, my prompt logic says: "If k connects to neither, assign impossible".
    # Here 2,3,4 connect to 'b' (1). So they are either 'a' or 'c'.
    # The conflict arises in VERIFY: if we pick 2='a', 3='a', 4='c'. Then 2 and 3 are 'a'-'a' but have NO edge. This fails verify.
    # So valid should be 0.
    
    if dut.valid.value != 0:
        # Note: The simplified logic in prompt might miss this if it greedily assigns.
        # Let's check what it produced.
        res = bytes([int(dut.result_string[i].value) for i in range(4)]).decode('ascii')
        print(f"Result (should be invalid): {res}")
        # If it produced valid=1, we might need to adjust the prompt logic to be stricter.
        # But for now, let's assume the VERIFY step catches it.
        # Actually, if Verify checks all edges, and we have non-edges, it must check non-edges too.
        # Prompt said: "Also check that non-edges are NOT connected".
        # So yes, it should fail.
        if dut.valid.value == 1: 
             raise TestFailure("Test 2 failed: Expected invalid (valid=0), got valid=1")
    
    print("Test 2 passed (correctly detected invalid)")

    # Test Case 3: N=4, M=4, Edges 1-2, 1-3, 1-4, 3-4
    # 1 connects to 2,3,4. 3 connects to 1,4. 4 connects to 1,3. 2 connects to 1.
    # Graph: 1 is center. 3-4 connected. 2 isolated from 3,4.
    # 1 is 'b'. 3-4 connected. 2 not connected to 3,4.
    # 2 must be 'a' or 'c'.
    # 3-4 connected. If 1 is 'b', neighbors are 'a' or 'c'.
    # 3 and 4 are connected. So they must be 'a'-'a', 'b'-'b', 'c'-'c', 'a'-'b', 'b'-'c'.
    # If 3 is 'a', 4 must be 'a' or 'b'. If 4 is 'b', it connects to 'c'.
    # 2 is not connected to 3,4. If 3='a', 2 cannot be 'a' (would connect). So 2='c'.
    # If 4='b', 2='c' connects to 'b' (edge exists? No, 2-4 is NOT an edge). Wait.
    # 2-4 is NOT an edge. If 2='c' and 4='b', they are adjacent, so MUST have edge. But they don't.
    # So 4 cannot be 'b' if 2 is 'c'.
    # So 4 must be 'a' (same as 3). Then 2='c' is fine (non-edge 'c'-'a').
    # Assignment: 1=b, 2=c, 3=a, 4=a.
    # Edges: 1-2 (b-c) OK. 1-3 (b-a) OK. 1-4 (b-a) OK. 3-4 (a-a) OK.
    # Non-edges: 2-3 (c-a) OK. 2-4 (c-a) OK.
    # This should be Valid.
    print("
Test 3: N=4, M=4, Edges 1-2, 1-3, 1-4, 3-4")
    dut.num_edges.value = 4
    dut.edge_u[0].value = 0; dut.edge_v[0].value = 1 # 1-2
    dut.edge_u[1].value = 0; dut.edge_v[1].value = 2 # 1-3
    dut.edge_u[2].value = 0; dut.edge_v[2].value = 3 # 1-4
    dut.edge_u[3].value = 2; dut.edge_v[3].value = 3 # 3-4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
    
    if dut.valid.value != 1:
        raise TestFailure("Test 3 failed: Expected valid")
    res = bytes([int(dut.result_string[i].value) for i in range(4)]).decode('ascii')
    print(f"Result: {res}")
    # Check if result matches one of valid possibilities
    # b,c,a,a (1=b, 2=c, 3=a, 4=a) or permutations.
    # Since we force 1 to be 'a' or 'c' if possible, it might pick different roots.
    # But 'b', 'c', 'a', 'a' is one valid string.
    # Let's just verify the string is consistent with the graph.
    # Mapping index: 0->1, 1->2, 2->3, 3->4.
    # string: s[0], s[1], s[2], s[3]
    # Edges: (0,1), (0,2), (0,3), (2,3).
    # Let's verify manually in python logic.
    import itertools
    valid_found = False
    chars = ['a', 'b', 'c']
    for p in itertools.product(chars, repeat=4):
        # Check edges
        ok = True
        if abs(ord(p[0]) - ord(p[1])) > 1: ok=False # 0-1
        if abs(ord(p[0]) - ord(p[2])) > 1: ok=False # 0-2
        if abs(ord(p[0]) - ord(p[3])) > 1: ok=False # 0-3
        if abs(ord(p[2]) - ord(p[3])) > 1: ok=False # 2-3
        # Check non-edges
        # 1-2, 1-3, 1-4 (Indices 1-2, 1-3, 1-4) -> Wait. Vertices 2, 3, 4. Indices 1, 2, 3.
        # Non-edges: (1,2), (1,3) -> indices (1,2), (1,3).
        if abs(ord(p[1]) - ord(p[2])) <= 1: ok=False
        if abs(ord(p[1]) - ord(p[3])) <= 1: ok=False
        if ok:
            valid_found = True
            if res == ''.join(p):
                print(f"Matched valid string: {res}")
                break
    else:
        # If not exact match, check if the result string is valid
        # (The prompt says 'any valid answer')
        p = list(res)
        ok = True
        if abs(ord(p[0]) - ord(p[1])) > 1: ok=False
        if abs(ord(p[0]) - ord(p[2])) > 1: ok=False
        if abs(ord(p[0]) - ord(p[3])) > 1: ok=False
        if abs(ord(p[2]) - ord(p[3])) > 1: ok=False
        if abs(ord(p[1]) - ord(p[2])) <= 1: ok=False
        if abs(ord(p[1]) - ord(p[3])) <= 1: ok=False
        if not ok:
             raise TestFailure(f"Test 3 failed: Result string {res} is invalid for the graph")

    print("All tests passed!")