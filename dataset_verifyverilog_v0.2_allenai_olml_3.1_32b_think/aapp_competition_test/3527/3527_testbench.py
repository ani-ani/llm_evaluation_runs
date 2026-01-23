import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

def calculate_expected_diameter(nodes, edges):
    # Python implementation of the logic to verify Verilog
    if not nodes:
        return 0
    
    # Build adjacency list
    adj = {i: [] for i in nodes}
    for u, v in edges:
        adj[u].append(v)
        adj[v].append(u)
    
    visited = set()
    diameters = []
    radii = []
    
    def bfs_farthest(start_node):
        q = [(start_node, 0)]
        local_visited = {start_node}
        farthest_node = start_node
        max_dist = 0
        while q:
            curr, dist = q.pop(0)
            if dist > max_dist:
                max_dist = dist
                farthest_node = curr
            for neighbor in adj[curr]:
                if neighbor not in local_visited:
                    local_visited.add(neighbor)
                    q.append((neighbor, dist + 1))
        return farthest_node, max_dist, local_visited

    while len(visited) < len(nodes):
        # Find an unvisited node
        start = None
        for n in nodes:
            if n not in visited:
                start = n
                break
        
        # BFS 1: Find farthest from start
        farthest_node, _, _ = bfs_farthest(start)
        
        # BFS 2: Find diameter
        _, diameter, component_visited = bfs_farthest(farthest_node)
        
        diameters.append(diameter)
        # Radius is ceil(diameter / 2)
        radii.append((diameter + 1) // 2)
        
        visited.update(component_visited)
    
    if len(diameters) == 1:
        return diameters[0]
    elif len(diameters) == 2:
        return max(diameters[0], diameters[1], radii[0] + radii[1] + 1)
    else:
        return 0

@cocotb.test()
async def test_network_optimizer(dut):
    """Test network diameter calculation"""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test Cases
    test_cases = [
        # Case 1: 6 nodes, 2 trees of size 3 (star shape 0-1, 0-2) and (3-4, 3-5)
        # Tree 1: 0 is center. Diam=2, Rad=1. Tree 2: 3 is center. Diam=2, Rad=1.
        # New Diam = max(2, 2, 1+1+1) = 3.
        {
            'nodes': 6, 
            'edges': [(0,1), (0,2), (3,4), (3,5)],
            'expected': 3
        },
        # Case 2: Chain of 4: 0-1-2-3 (Diam=3, Rad=2) and single node 4 (Diam=0, Rad=0)
        # New Diam = max(3, 0, 2+0+1)=3
        {
            'nodes': 5, 
            'edges': [(0,1), (1,2), (2,3)],
            'expected': 3
        },
        # Case 3: Chain of 3: 0-1-2 (Diam=2, Rad=1) and Chain of 3: 3-4-5 (Diam=2, Rad=1)
        # New Diam = max(2, 2, 1+1+1)=3
        {
            'nodes': 6, 
            'edges': [(0,1), (1,2), (3,4), (4,5)],
            'expected': 3
        },
        # Case 4: Chain of 5: 0-1-2-3-4 (Diam=4, Rad=2) and Chain of 2: 5-6 (Diam=1, Rad=1)
        # New Diam = max(4, 1, 2+1+1)=4
        {
            'nodes': 7, 
            'edges': [(0,1), (1,2), (2,3), (3,4), (5,6)],
            'expected': 4
        },
        # Case 5: Single component 0-1-2 (Diam=2)
        {
            'nodes': 3, 
            'edges': [(0,1), (1,2)],
            'expected': 2
        }
    ]

    passed = 0
    total = len(test_cases)

    for i, tc in enumerate(test_cases):
        # Prepare inputs
        node_count = tc['nodes']
        edges = tc['edges']
        expected = tc['expected']
        
        # Initialize arrays (16 deep)
        edges_u = [0] * 16
        edges_v = [0] * 16
        for idx, (u, v) in enumerate(edges):
            edges_u[idx] = u
            edges_v[idx] = v
        
        dut.node_count.value = node_count
        dut.edge_count.value = len(edges)
        
        # Drive inputs
        for j in range(16):
            dut.edges_u[j].value = edges_u[j]
            dut.edges_v[j].value = edges_v[j]
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 5000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 5000:
            print(f"Test {i+1} FAILED: Timeout")
            continue
            
        result = int(dut.result.value)
        
        if result == expected:
            passed += 1
            print(f"Test {i+1} PASSED: Input nodes={node_count}, edges={len(edges)}. Result {result} == Expected {expected}")
        else:
            print(f"Test {i+1} FAILED: Input nodes={node_count}, edges={len(edges)}. Result {result} != Expected {expected}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
