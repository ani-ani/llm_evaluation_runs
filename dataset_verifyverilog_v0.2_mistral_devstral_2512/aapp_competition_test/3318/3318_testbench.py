import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def pack_edges(edge_list, N):
    """Pack list of parent indices into 15*4-bit field"""
    packed = 0
    for i, parent in enumerate(edge_list):
        # Edge i corresponds to node i+1, store in bits [4*i+3 : 4*i]
        packed |= (parent & 0xF) << (4 * i)
    return packed

def compute_max_marked(N, D, parents):
    """Brute force compute max marked nodes for validation"""
    # Build adjacency
    adj = [[] for _ in range(N)]
    for i in range(1, N):
        p = parents[i-1]
        adj[i].append(p)
        adj[p].append(i)
    
    # Compute all-pairs distances using BFS
    dist = [[0]*N for _ in range(N)]
    for i in range(N):
        queue = [(i, 0)]
        visited = {i}
        while queue:
            node, d = queue.pop(0)
            dist[i][node] = d
            for neighbor in adj[node]:
                if neighbor not in visited:
                    visited.add(neighbor)
                    queue.append((neighbor, d+1))
    
    # Enumerate all subsets
    best = 0
    for mask in range(1 << N):
        valid = True
        marked = [i for i in range(N) if mask & (1 << i)]
        # Check all pairs
        for i in range(len(marked)):
            for j in range(i+1, len(marked)):
                if dist[marked[i]][marked[j]] < D:
                    valid = False
                    break
            if not valid:
                break
        if valid:
            best = max(best, len(marked))
    return best

@cocotb.test()
async def test_tree_marking(dut):
    """Test tree marking module with multiple test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.D.value = 0
    dut.edges.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (N, D, parents, expected)
        (4, 3, [0, 0, 1], 2),  # Sample 1
        (3, 1000, [0, 0], 1),  # Sample 2
        (18, 3, [0,1,1,3,1,4,2,1,0,2,0,0,1,1,3,0,3], 5),  # Sample 3
        (18, 2, [0,0,0,1,2,2,3,3,1,3,4,1,1,4,2,4,0], 13),  # Sample 4
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (N, D, parents, expected) in enumerate(test_cases):
        print(f"
Test case {i+1}: N={N}, D={D}")
        
        # Pack edges
        edges_packed = pack_edges(parents, N)
        print(f"  Expected: {expected}, Packed edges: 0x{edges_packed:X}")
        
        # Start computation
        dut.N.value = N
        dut.D.value = D
        dut.edges.value = edges_packed
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100000  # Large timeout for slow computations
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done")
        
        # Read result
        result = int(dut.result.value)
        
        # Compute expected using Python for verification
        python_result = compute_max_marked(N, D, parents)
        
        print(f"  Module result: {result}, Python result: {python_result}")
        
        if result == expected and python_result == expected:
            print(f"  ✓ PASS")
            passed += 1
        else:
            print(f"  ✗ FAIL - Expected {expected}, got {result}")
            if python_result != expected:
                print(f"    WARNING: Python validation also got {python_result}")
    
    print(f"
{'='*50}")
    print(f"SUMMARY: {passed}/{total} tests passed")
    print(f"{'='*50}")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
