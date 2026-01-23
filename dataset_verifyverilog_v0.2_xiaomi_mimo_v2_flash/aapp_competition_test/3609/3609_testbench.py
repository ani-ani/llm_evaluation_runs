import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def solve_py(n, edges):
    # Python reference implementation for testbench verification
    m = len(edges)
    result = [-1] * m
    
    # Tracking connectivity
    # Left tree rooted at 1, edges u->v with u < v
    # Right tree rooted at n, edges v->u (conceptually) with u < v, so parent v > child u
    
    def backtrack(idx, left_parents, right_parents):
        if idx == m:
            # Check if both trees span all nodes
            # Check Left: Node 1 is root. All nodes reachable?
            # Check Right: Node n is root. All nodes reachable?
            
            # Left check: Build adjacency and BFS from 1
            visited_l = [False] * (n + 1)
            adj_l = [[] for _ in range(n + 1)]
            for i in range(m):
                if result[i] == 'L':
                    u, v = edges[i]
                    adj_l[u].append(v)
            # BFS
            q = [1]
            visited_l[1] = True
            head = 0
            while head < len(q):
                u = q[head]
                head += 1
                for v in adj_l[u]:
                    if not visited_l[v]:
                        visited_l[v] = True
                        q.append(v)
            if not all(visited_l[1:]):
                return False
                
            # Right check: Build adjacency and BFS from n
            visited_r = [False] * (n + 1)
            adj_r = [[] for _ in range(n + 1)]
            for i in range(m):
                if result[i] == 'R':
                    u, v = edges[i]
                    # Edge (u, v) u<v. Right tree: parent v -> child u
                    adj_r[v].append(u)
            # BFS
            q = [n]
            visited_r[n] = True
            head = 0
            while head < len(q):
                u = q[head]
                head += 1
                for v in adj_r[u]:
                    if not visited_r[v]:
                        visited_r[v] = True
                        q.append(v)
            if not all(visited_r[1:]):
                return False
            return True

        u, v = edges[idx]
        
        # Try Left (u -> v)
        # We need to ensure no cycles. Since u < v, and tree flows from 1 to larger nodes, 
        # we just need to check if v is already reachable from u (which implies cycle if u->v added) 
        # But simpler: check if adding edge u->v connects two nodes already in Left tree.
        # However, we can just build the tree and check connectivity at the end for small N.
        # To prune early: check if v is already a descendant of u? Hard without full tree.
        # Check: if u is not reachable from 1 yet, and u != 1? Then can't use u as parent.
        # Actually, if u is not in Left tree, we can't start a branch there (except u=1).
        # But wait, if we assign (u,v) to Left, we need u to be connected to 1.
        # Let's track reachability explicitly to prune.
        
        # Optimization: Pass reachable sets
        # But for n=8, we can just do full build at end.
        # Let's do full check at end for simplicity, as m is small.
        
        # Just try L, then R
        result[idx] = 'L'
        if backtrack(idx + 1, left_parents, right_parents):
            return True
            
        result[idx] = 'R'
        if backtrack(idx + 1, left_parents, right_parents):
            return True
            
        result[idx] = -1
        return False

    if backtrack(0, None, None):
        return "".join(result)
    else:
        return "impossible"

@cocotb.test()
async def test_tree_assignment(dut):
    # Test case 1 from prompt
    n1 = 5
    edges1 = [(1,2), (2,5), (2,3), (1,3), (3,5), (4,5), (3,4), (1,3)]
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = n1
    for i in range(15):
        if i < len(edges1):
            dut.edge_u[i].value = edges1[i][0]
            dut.edge_v[i].value = edges1[i][1]
        else:
            dut.edge_u[i].value = 0
            dut.edge_v[i].value = 0
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await Timer(20, units='ns')
    
    # Reset
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Test 1: Module did not finish in time"
    assert dut.valid.value == 1, "Test 1: Expected valid solution"
    
    # Check output mask
    l_mask = dut.l_mask.value
    # Verify against reference
    ref = solve_py(n1, edges1)
    print(f"Test 1: Module output mask={bin(l_mask)}, Reference={ref}")
    
    # Check string
    output_str = ""
    for i in range(len(edges1)):
        if (l_mask >> i) & 1:
            output_str += 'L'
        else:
            output_str += 'R'
    
    # We know a solution exists, so just check validity of our output
    # Since we might not match exactly the reference string (multiple solutions),
    # we can re-run verification logic here or trust the module if we trust the logic.
    # Let's trust the module for now, but verify it's not 'impossible'.
    # Actually, we can verify the structure:
    
    # Verify Left tree (edges where l_mask bit is 1) connects 1 to all, parent < child
    adj_l = [[] for _ in range(n1 + 1)]
    for i in range(len(edges1)):
        if (l_mask >> i) & 1:
            u, v = edges1[i]
            if u > v: u, v = v, u # Should not happen based on input spec, but just in case
            adj_l[u].append(v)
    
    # BFS from 1
    visited = [False] * (n1 + 1)
    q = [1]
    visited[1] = True
    head = 0
    while head < len(q):
        u = q[head]
        head += 1
        for v in adj_l[u]:
            if not visited[v]:
                visited[v] = True
                q.append(v)
    assert all(visited[1:]), f"Test 1: Left tree doesn't span. Visited: {visited}"
    
    # Verify Right tree (edges where l_mask bit is 0) connects n to all, parent > child
    # Input edges are (u, v) with u < v. Right tree uses (u, v) as parent v -> child u
    adj_r = [[] for _ in range(n1 + 1)]
    for i in range(len(edges1)):
        if not ((l_mask >> i) & 1):
            u, v = edges1[i]
            adj_r[v].append(u)
    
    visited = [False] * (n1 + 1)
    q = [n1]
    visited[n1] = True
    head = 0
    while head < len(q):
        u = q[head]
        head += 1
        for v in adj_r[u]:
            if not visited[v]:
                visited[v] = True
                q.append(v)
    assert all(visited[1:]), f"Test 1: Right tree doesn't span. Visited: {visited}"

    print("Test 1 passed")

    # Test case 2: Impossible
    n2 = 3
    edges2 = [(1,2), (1,2), (1,3), (1,3)]
    
    dut.n.value = n2
    for i in range(15):
        if i < len(edges2):
            dut.edge_u[i].value = edges2[i][0]
            dut.edge_v[i].value = edges2[i][1]
        else:
            dut.edge_u[i].value = 0
            dut.edge_v[i].value = 0
    
    # Reset and run
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Test 2: Module did not finish in time"
    assert dut.valid.value == 0, "Test 2: Expected invalid solution"
    print("Test 2 passed")
