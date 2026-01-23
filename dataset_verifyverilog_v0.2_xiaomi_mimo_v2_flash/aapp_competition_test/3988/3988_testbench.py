import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

def to_binary_adj(n_nodes, edges):
    # Helper to convert edge list to bitmasks for the testbench
    # edges: list of (type, u, v)
    # type: 1=directed, 2=undirected
    mask = 0
    from_arr = [0]*16
    to_arr = [0]*16
    type_arr = [0]*16
    
    for i, (t, u, v) in enumerate(edges):
        if i >= 16: break
        mask |= (1 << i)
        # Adjust to 0-indexed
        from_arr[i] = u - 1
        to_arr[i] = v - 1
        type_arr[i] = 1 if t == 2 else 0 # 1 if undirected, 0 if directed
        
    return mask, from_arr, to_arr, type_arr

def reference_sol(n, m, s, edges, mode):
    # mode: 'max' or 'min'
    adj = {}
    undirected_edges = []
    
    # Build graph
    u_edge_idx = 0
    for i, (t, u, v) in enumerate(edges):
        if t == 1:
            # Directed
            if u not in adj: adj[u] = []
            adj[u].append((v, 'dir', -1))
        else:
            # Undirected
            undirected_edges.append((u, v))
            if mode == 'max':
                # In max, undirected is bidirectional
                if u not in adj: adj[u] = []
                if v not in adj: adj[v] = []
                adj[u].append((v, 'undir', u_edge_idx))
                adj[v].append((u, 'undir', u_edge_idx))
            else:
                # In min, we arbitrarily orient u->v (plus) initially for reachability check
                # Actually, the goal is to minimize reachability. 
                # The standard algorithm is: treat undirected edges as u->v.
                # If we can reach u, we can reach v. 
                # This limits the spread compared to max.
                if u not in adj: adj[u] = []
                adj[u].append((v, 'undir', u_edge_idx))
            u_edge_idx += 1
            
    # BFS
    reachable = set([s])
    queue = [s]
    visited = {s}
    
    orientation = ['+'] * len(undirected_edges)
    
    while queue:
        curr = queue.pop(0)
        if curr not in adj: continue
        for neighbor, edge_type, idx in adj[curr]:
            if mode == 'max':
                if neighbor not in visited:
                    visited.add(neighbor)
                    reachable.add(neighbor)
                    queue.append(neighbor)
                
                # Orientation logic for max:
                # If traversing u->v, set to +
                # If traversing v->u, set to -
                # Note: The specific Python code in the prompt implies that during DFS,
                # it sets the orientation based on the traversal direction.
                # In max, we traverse both ways, so orientation is set to whichever direction is traversed first.
                # If we traverse u->v, it's +. If v->u, it's -.
                if edge_type == 'undir':
                    if curr == undirected_edges[idx][0] and neighbor == undirected_edges[idx][1]:
                        orientation[idx] = '+'
                    elif curr == undirected_edges[idx][1] and neighbor == undirected_edges[idx][0]:
                        orientation[idx] = '-'
            
            else: # min
                # In min, we only traverse forward u->v for undirected
                # If we have edge (u, v), we traverse u->v only.
                # So we only reach v if we are at u.
                # Orientation for reached edges is + (u->v).
                if edge_type == 'undir':
                    # For min, we effectively only allow traversal u->v
                    # So if curr == u and neighbor == v, we traverse.
                    # If curr == v and neighbor == u, we DO NOT traverse.
                    if curr == undirected_edges[idx][0] and neighbor == undirected_edges[idx][1]:
                        if neighbor not in visited:
                            visited.add(neighbor)
                            reachable.add(neighbor)
                            queue.append(neighbor)
                        orientation[idx] = '+'
                    # If we somehow reach v and there is an edge (u, v), we don't go back to u.
                    # But wait, the python code for min sets orientation based on what?
                    # The provided code snippet for minimization:
                    # if k < 0: ans[-k-1] = '+' 
                    # if k > 0: ans[k-1] = '-'
                    # This implies that if it traverses, it sets opposite of max?
                    # Actually, let's look at the Python logic again.
                    # DFS(x, flag):
                    # flag 1 for max: travesal condition `if flag==1 or k==0` -> visits all.
                    # flag -1 for min: travesal condition `if flag==1 or k==0` -> but wait, flag is -1.
                    # The logic `if flag==1 or k==0` means for flag=-1, it only visits if `k==0` (directed edges).
                    # It does NOT visit undirected edges in the DFS stack in the minimization pass.
                    # BUT it assigns orientation.
                    # For minimization, it assigns based on the edges CONNECTED to reachable nodes.
                    # It finds reachable nodes using ONLY directed edges.
                    # Then, for undirected edges connecting to these nodes, it assigns orientation.
                    # So:
                    # 1. Find reachable using only directed edges.
                    # 2. For every undirected edge (u, v):
                    #    If u is reachable but v is not: Orient u->v. Reachable count = size(reachable) + 0.
                    #    If v is reachable but u is not: Orient v->u. Reachable count = size(reachable) + 0.
                    #    If both reachable: Orient u->v. Reachable count = size(reachable).
                    #    If neither reachable: Orient u->v. Reachable count = size(reachable).
                    # The reachability count is just the size of the reachable set using directed edges.
                    # The orientation string: 
                    #    If u in reachable and v not in reachable: set + (u->v) or - (v->u).
                    #    The Python code for min:
                    #    It does a DFS on directed edges only (k==0).
                    #    It marks reachable.
                    #    Then it iterates edges. 
                    #    Actually, the provided code snippet for min is:
                    #    if k < 0: ans[-k-1] = '+'  
                    #    if k > 0: ans[k-1] = '-'
                    #    This sets the orientation.
                    #    Let's trace `k`. 
                    #    Undirected (u, v) -> graph[u] has (v, k), graph[v] has (u, -k).
                    #    So k is +index for u->v, -index for v->u.
                    #    In the min DFS, we only process if k==0 (directed edges).
                    #    Wait, the snippet:
                    #    def dfs1(x):
                    #      ... 
                    #      for j, k in graph[i]:
                    #        if vis[j]==0:
                    #          if k < 0: ans[-k-1] = '+'
                    #          elif k > 0: ans[k-1] = '-'
                    #          if k == 0: s.append(j) ...
                    #    This means:
                    #    We iterate over ALL edges connected to reachable nodes.
                    #    Even if we don't traverse undirected edges (k!=0), we see them.
                    #    If we see an edge k (u->v), we assign orientation based on k.
                    #    If k > 0 (it's the u->v representation), we set ans[k-1] = '-'.
                    #    Wait, if k > 0 is the edge (u,v) stored at u. 
                    #    If we are at u (reachable), and we see edge (u,v) with k > 0.
                    #    We set ans[k-1] = '-'.
                    #    The output ' - ' corresponds to v->u.
                    #    Why v->u? To ensure we don't go u->v (which would expand reachable set).
                    #    So we orient v->u. Since u is reachable, and we go v->u, we don't reach v from u.
                    #    Wait, we want to minimize reachability. 
                    #    If u is reachable and v is not. We don't want to go u->v. We want to go v->u.
                    #    v->u means we go from v to u. But we can't reach v to start with.
                    #    So we don't reach v. Correct.
                    #    What if both are reachable? Then it doesn't matter.
                    #    What if neither reachable? Then orientation doesn't matter for reachability count.
                    #    
                    #    So the logic for MIN:
                    #    1. Find reachable set R using ONLY directed edges.
                    #    2. For each undirected edge (u, v):
                    #       If u in R and v not in R: Orient u->v (+). Wait, the code does '-'.
                    #       Let's check the output Example 2:
                    #       Min output: 2, +-+.
                    #       Graph: s=3.
                    #       Directed: 4->5, 4->1, 3->1.
                    #       Undirected: (2,6), (3,4), (2,3).
                    #       Reachable from 3 via directed: 3, 1.
                    #       Undirected edges:
                    #       (2,6): neither reachable. Output '+'. (Code assigns based on first visit? No)
                    #       (3,4): 3 is reachable, 4 is not. Output '-'. (Code assigns '-')
                    #       (2,3): 3 is reachable, 2 is not. Output '+'. (Code assigns '+')
                    #       Wait, the code logic:
                    #       From 3: edges? 
                    #       3 has directed (3,1). 
                    #       3 has undirected (3,4) -> stored in graph[3] as (4, k1) and graph[4] as (3, -k1).
                    #       3 has undirected (2,3) -> stored in graph[3] as (2, k2) and graph[2] as (3, -k2).
                    #       In DFS(3):
                    #       Visit 3. 
                    #       Iterate edges:
                    #       Edge (4, k1): k1 > 0. Code sets ans[k1-1] = '-'. (Matches output '-')
                    #       Edge (2, k2): k2 > 0. Code sets ans[k2-1] = '+'. (Matches output '+')
                    #       Edge (1, 0): Traversed. Reach 1.
                    #       From 1: 
                    #       Iterates edges? 
                    #       1 is connected to 3 (edge -k2)? No.
                    #       1 is connected to 4 (edge -k1)? No.
                    #       So the result is based on what the reachable nodes see.
                    #       If a reachable node sees an undirected edge (u, v), and the edge is stored in that node as (v, sign), 
                    #       it sets orientation. 
                    #       The sign in the code: 
                    #       If k > 0 (u->v stored in u): set ans[k-1] = '+'.
                    #       If k < 0 (v->u stored in u): set ans[-k-1] = '-'.
                    #       Wait, let's re-read the code.
                    #       def dfs(x, flag):
                    #         ...
                    #         for j, k in graph[i]:
                    #           if vis[j] == 0:
                    #             if k*flag < 0: ans[abs(k)-1] = '-'
                    #             elif k*flag > 0: ans[abs(k)-1] = '+'
                    #             if flag==1 or k==0: ...
                    #       Max (flag 1):
                    #         k*1 > 0 -> k > 0 -> ans = '+'
                    #         k*1 < 0 -> k < 0 -> ans = '-'
                    #       Min (flag -1):
                    #         k*(-1) > 0 -> k < 0 -> ans = '+'
                    #         k*(-1) < 0 -> k > 0 -> ans = '-'
                    #       So for Min:
                    #         If we see edge with k < 0 (v->u), we set '+' (meaning u->v? No, the problem says + is u->v).
                    #         If we see edge with k > 0 (u->v), we set '-' (meaning v->u).
                    #       Wait, what is the default mapping of + and -?
                    #       + : u -> v (from input order)
                    #       - : v -> u
                    #       So for edge (u, v) input:
                    #       If we want u->v, output '+'.
                    #       If we want v->u, output '-'.
                    #       In the graph storage:
                    #       graph[u].append((v, k)) # k > 0
                    #       graph[v].append((u, -k)) # -k < 0
                    #       In Min:
                    #       If we are at u (reachable), we see (v, k > 0). Code sets '-'. This means v->u.
                    #       If we are at v (reachable), we see (u, -k < 0). Code sets '+'. This means u->v.
                    #       In both cases, the direction is set from the non-reachable node TO the reachable node.
                    #       So the edge goes into the reachable component, not out of it.
                    #       This minimizes reachability.
                    #       So the Min Logic is:
                    #       1. Mark reachable nodes using Directed Edges.
                    #       2. For each undirected edge (u, v):
                    #          If u is reachable, set orientation to v->u ('-').
                    #          If v is reachable, set orientation to u->v ('+').
                    #       If both are reachable, which one gets set? 
                    #       The code iterates from all reachable nodes. The last one processed wins.
                    #       In the example, (2,3): Reachable={3,1}. 
                    #       At 3, sees (2, k>0). Sets '-'. 
                    #       At 2 (not reachable), nothing.
                    #       Wait, output is '+' for (2,3). 
                    #       Example 2 output min: +-+
                    #       Undirected edges: (2,6), (3,4), (2,3).
                    #       Indices: 0, 1, 2.
                    #       Output: + - +
                    #       Edge 0 (2,6): +
                    #       Edge 1 (3,4): -
                    #       Edge 2 (2,3): +
                    #       Reachable from 3 (directed): 3, 1.
                    #       Edge 0 (2,6): Neither reachable. 
                    #       Edge 1 (3,4): 3 is reachable. Should be v->u? 3 is u? Input is 3 4. u=3, v=4.
                    #         3 is reachable. Code at 3 sees (4, k>0). Sets '-'. Correct.
                    #         Direction: 4 -> 3. (Doesn't expand from 3).
                    #       Edge 2 (2,3): 3 is reachable. Input is 2 3. u=2, v=3.
                    #         3 is reachable. Code at 3 sees (2, k>0)? 
                    #         Input 2 3. u=2, v=3. Stored at u=2: (3, k). At v=3: (2, -k).
                    #         So at node 3, we see (2, -k). k > 0, so -k < 0.
                    #         Code: k*(-1) < 0? No. k*(-1) > 0? Yes (since k>0). 
                    #         Wait, k in loop is -k if we are at 3. 
                    #         k_loop = -k.
                    #         Code: if k_loop < 0: ...
                    #         If we are at 3, we see (2, -k). -k is negative.
                    #         So condition `k_loop < 0` is true.
                    #         Code sets ans = '-'.
                    #         But wait, example output is '+' for edge 2.
                    #         Let's re-check the code logic from the prompt.
                    #         The Python code in the prompt is `def dfs(x,flag=1):`.
                    #         Min calls with flag=-1.
                    #         Inside loop: `if k*flag<0: ans[abs(k)-1]='-'`
                    #         `elif k*flag>0: ans[abs(k)-1]='+'`
                    #         For edge (2,3) at node 3:
                    #         k = -k_val.
                    #         k * flag = (-k_val) * (-1) = k_val.
                    #         k_val > 0. So k*flag > 0.
                    #         This triggers `elif`, setting ans = '+'
                    #         This matches the example output '+' for edge 2.
                    #         So at node 3 (reachable), seeing edge to 2 (not reachable), sets '+' (u->v? or v->u?).
                    #         Edge (2,3) input: u=2, v=3.
                    #         Stored at 3 as (2, -k). 
                    #         Output '+'. 
                    #         The Python code sets '+'.
                    #         What does '+' mean for input (2,3)? It means u->v, so 2->3.
                    #         If we are at 3 (reachable), and we orient 2->3, we don't expand from 3 to 2.
                    #         Correct.
                    #         So the rule for Min is:
                    #         Reachable nodes see connected undirected edges.
                    #         If an edge connects a reachable node to an unreachable node:
                    #         Orient it FROM the unreachable node TO the reachable node.
                    #         This ensures the edge enters the component, not leaves it.
                    #         
                    #         So the implementation:
                    #         1. Calculate Reachable set R using Directed Edges only.
                    #         2. For each undirected edge i (u, v):
                    #            If u in R and v not in R: Output '-'. (Meaning v->u. From unreachable v to reachable u). 
                    #            If v in R and u not in R: Output '+'. (Meaning u->v. From unreachable u to reachable v).
                    #            If both in R: Output '+' (u->v). Doesn't matter.
                    #            If neither in R: Output '+' (u->v). Doesn't matter.
                    
                    #    
                    #    
                    #    
                    
                    
    # Implementation of reference logic
    
    # 1. Reachability via Directed Edges only
    # This determines the set of reachable vertices for BOTH max and min (for min, this is the result count)
    # But wait, for Max, we use ALL edges (bidirectional). For Min, we use Directed only.
    
    # Let's re-implement carefully based on the examples.
    
    # MAX:
    # Use all edges. Undirected treated as bidirectional.
    # Count reachable.
    # Orientation: 
    #   If we traverse u->v (input order), set '+'.
    #   If we traverse v->u, set '-'.
    
    # MIN:
    # Use only Directed edges for reachability count.
    # Orientation:
    #   For each undirected edge (u, v):
    #     If u is reachable and v is not: set orientation to '-'.
    #     If v is reachable and u is not: set orientation to '+'.
    #     If both or neither reachable: set '+'.
    
    # Note: The Python code does a full DFS/Traversal but restricts stack pushes for Min.
    # But it still iterates edges to set orientation.
    
    # Let's simulate the python logic exactly.
    
    # Data structure: Graph: node -> list of (neighbor, k)
    # k > 0 means input edge index + 1 (u->v)
    # k < 0 means -input edge index - 1 (v->u)
    # k = 0 means directed.
    
    graph_py = [[] for _ in range(n)]
    u_edge_idx = 0
    for i, (t, u, v) in enumerate(edges):
        u -= 1
        v -= 1
        if t == 1:
            # Directed
            graph_py[u].append((v, 0))
        else:
            # Undirected
            k = u_edge_idx + 1
            graph_py[u].append((v, k))
            graph_py[v].append((u, -k))
            u_edge_idx += 1
            
    def run_py_dfs(flag):
        vis = [0]*n
        ans = ['+']*u_edge_idx
        stack = [s-1]
        vis[s-1] = 1
        count = 1
        
        while stack:
            curr = stack.pop()
            for neighbor, k in graph_py[curr]:
                if vis[neighbor] == 0:
                    # Orientation setting logic
                    # Logic from prompt: if k*flag < 0: ans[abs(k)-1]='-' ...
                    # Note: The prompt code checks `if vis[j]==0` BEFORE setting orientation in some versions, 
                    # but strictly:
                    # if vis[j] == 0:
                    #    set orientation
                    #    if condition: push to stack
                    
                    # The provided code snippet for Max/Min uses the same loop for setting orientation.
                    # It sets orientation if neighbor is unvisited.
                    
                    if k*flag < 0:
                        ans[abs(k)-1] = '-'
                    elif k*flag > 0:
                        ans[abs(k)-1] = '+'
                    
                    # Traversal condition
                    # Flag 1 (Max): visits if k != 0 (undirected) or k == 0 (directed). Always true.
                    # Flag -1 (Min): visits if flag == 1 OR k == 0. 
                    #    Since flag != 1, it visits only if k == 0 (Directed edges).
                    
                    if flag == 1 or k == 0:
                        stack.append(neighbor)
                        vis[neighbor] = 1
                        count += 1
        
        return count, ''.join(ans)
        
    count_max, orient_max = run_py_dfs(1)
    count_min, orient_min = run_py_dfs(-1)
    
    if mode == 'max':
        return count_max, orient_max
    else:
        return count_min, orient_min

@cocotb.test()
async def test_graph_planner(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start_max.value = 0
    dut.start_min.value = 0
    dut.s.value = 0
    dut.num_vertices.value = 0
    dut.num_undirected.value = 0
    dut.edge_valid.value = 0
    
    for i in range(16):
        setattr(dut, f'edge_from_{i}', 0)
        setattr(dut, f'edge_to_{i}', 0)
        setattr(dut, f'edge_type_{i}', 0)
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        {"input": "2 2 1
1 1 2
2 2 1", "desc": "Simple case"},
        {"input": "6 6 3
2 2 6
1 4 5
2 3 4
1 4 1
1 3 1
2 2 3", "desc": "Example 2"},
        {"input": "5 5 5
2 5 3
1 2 3
1 4 5
2 5 2
1 2 1", "desc": "Disjoint components"},
        {"input": "2 5 1
2 1 2
2 1 2
2 1 2
2 1 2
2 1 2", "desc": "Multiple undirected edges"}
    ]
    
    passed = 0
    total = len(test_cases) * 2
    
    for case in test_cases:
        lines = case["input"].strip().split('
')
        n, m, s = map(int, lines[0].split())
        edges = []
        for i in range(1, len(lines)):
            t, u, v = map(int, lines[i].split())
            edges.append((t, u, v))
            
        # Prepare inputs
        dut.s.value = s - 1
        dut.num_vertices.value = n
        
        # Extract undirected edges for orientation output
        undirected_edges = [e for e in edges if e[0] == 2]
        dut.num_undirected.value = len(undirected_edges)
        
        # Setup graph inputs
        dut.edge_valid.value = 0
        for i, (t, u, v) in enumerate(edges):
            if i >= 16: break
            dut.edge_valid.value |= (1 << i)
            # Use getattr/setattr for dynamic array access if needed, or direct indexing
            # Verilator/VPI might expose them as array or as individual signals.
            # The prompt specifies `input [2:0] edge_from [15:0]`. 
            # In cocotb, for arrays, it's usually dut.edge_from[i].value = ...
            dut.edge_from[i].value = u - 1
            dut.edge_to[i].value = v - 1
            dut.edge_type[i].value = 1 if t == 2 else 0
            
        # --- MAX TEST ---
        dut.start_max.value = 1
        await RisingEdge(dut.clk)
        dut.start_max.value = 0
        
        # Wait for valid
        timeout = 0
        while not dut.valid.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 100:
            dut._log.error("Max timeout")
            continue
            
        # Get outputs
        count_hw = int(dut.reachable_count.value)
        orient_hw = int(dut.undirected_orientation.value)
        
        # Reference
        ref_count, ref_orient = reference_sol(n, m, s, edges, 'max')
        
        # Check count
        if count_hw == ref_count:
            passed += 1
        else:
            dut._log.error(f"Max count mismatch: HW={count_hw}, Ref={ref_count}")
            
        # Check orientation (only for undirected edges)
        # Convert mask to string
        orient_str = ''
        for i in range(len(undirected_edges)):
            if (orient_hw >> i) & 1:
                orient_str += '+'
            else:
                orient_str += '-'
        
        if orient_str == ref_orient:
            passed += 1
        else:
            dut._log.error(f"Max orient mismatch: HW={orient_str}, Ref={ref_orient}")
            
        await RisingEdge(dut.clk)
        
        # --- MIN TEST ---
        dut.start_min.value = 1
        await RisingEdge(dut.clk)
        dut.start_min.value = 0
        
        timeout = 0
        while not dut.valid.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 100:
            dut._log.error("Min timeout")
            continue
            
        count_hw = int(dut.reachable_count.value)
        orient_hw = int(dut.undirected_orientation.value)
        
        ref_count, ref_orient = reference_sol(n, m, s, edges, 'min')
        
        if count_hw == ref_count:
            passed += 1
        else:
            dut._log.error(f"Min count mismatch: HW={count_hw}, Ref={ref_count}")
            
        orient_str = ''
        for i in range(len(undirected_edges)):
            if (orient_hw >> i) & 1:
                orient_str += '+'
            else:
                orient_str += '-'
                
        if orient_str == ref_orient:
            passed += 1
        else:
            dut._log.error(f"Min orient mismatch: HW={orient_str}, Ref={ref_orient}")
            
        await RisingEdge(dut.clk)

    print(f"
*** SUMMARY: {passed}/{total} tests passed ***")
    assert passed == total, "Some tests failed"
