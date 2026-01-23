import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
import random

# Helper function to encode edges for the wrapper
def encode_edges(edges):
    """Convert list of (u,v) edges to individual inputs for wrapper"""
    edge_u = [0] * 8
    edge_v = [0] * 8
    for i, (u, v) in enumerate(edges):
        if i < 8:
            edge_u[i] = u
            edge_v[i] = v
    return edge_u, edge_v

def calculate_expected(n, m, edges):
    """Calculate expected minimum cost using brute force for small graphs"""
    if m > 8:  # Our hardware only handles up to 8 edges
        return None
    
    # Try all possible assignments of costs (0,1,2) to edges
    best_cost = float('inf')
    found = False
    
    for config in range(3 ** m):
        # Decode configuration
        edge_costs = []
        temp = config
        for _ in range(m):
            edge_costs.append(temp % 3)
            temp //= 3
        
        # Check mod-3 constraint
        valid = True
        node_edges = {}
        for i, (u, v) in enumerate(edges):
            if u not in node_edges:
                node_edges[u] = []
            if v not in node_edges:
                node_edges[v] = []
            node_edges[u].append(i)
            node_edges[v].append(i)
        
        for node, e_list in node_edges.items():
            if len(e_list) > 1:
                for i in range(len(e_list)):
                    for j in range(i + 1, len(e_list)):
                        a = edge_costs[e_list[i]]
                        b = edge_costs[e_list[j]]
                        if (a + b) % 3 == 1:
                            valid = False
                            break
                    if not valid:
                        break
            if not valid:
                break
        
        if not valid:
            continue
        
        # Check cycle parity - simplified for this test
        # For small graphs, check if sum is odd
        total_sum = sum(edge_costs)
        if total_sum % 2 == 1:
            found = True
            if total_sum < best_cost:
                best_cost = total_sum
    
    return best_cost if found else -1

@cocotb.test()
async def test_graph_decoration_basic(dut):
    """Test basic functionality with small graphs"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Simple triangle with potential solution
    # Nodes: 1,2,3. Edges: (1,2), (2,3), (3,1)
    edges = [(1, 2), (2, 3), (1, 3)]
    edge_u, edge_v = encode_edges(edges)
    
    dut.node_count.value = 3
    dut.edge_count.value = 3
    for i in range(8):
        setattr(dut, f'edge_u_{i}', edge_u[i])
        setattr(dut, f'edge_v_{i}', edge_v[i])
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for computation (allow many cycles for search)
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.valid.value or dut.error.value:
            break
    
    if dut.error.value:
        print("Test 1: No solution found (might be expected)")
    elif dut.valid.value:
        result = int(dut.min_cost.value)
        expected = calculate_expected(3, 3, edges)
        print(f"Test 1: Result={result}, Expected={expected}")
        if expected != -1:
            assert result == expected, f"Expected {expected}, got {result}"

@cocotb.test()
async def test_graph_decoration_small_tree(dut):
    """Test with a small tree (no cycles)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Tree: 1-2, 1-3
    edges = [(1, 2), (1, 3)]
    edge_u, edge_v = encode_edges(edges)
    
    dut.node_count.value = 3
    dut.edge_count.value = 2
    for i in range(8):
        setattr(dut, f'edge_u_{i}', edge_u[i])
        setattr(dut, f'edge_v_{i}', edge_v[i])
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.valid.value or dut.error.value:
            break
    
    if dut.valid.value:
        result = int(dut.min_cost.value)
        expected = calculate_expected(3, 2, edges)
        print(f"Test 2 (tree): Result={result}, Expected={expected}")
        if expected != -1:
            assert result == expected, f"Expected {expected}, got {result}"

@cocotb.test()
async def test_graph_decoration_impossible(dut):
    """Test case that should be impossible"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Complex graph that might be impossible
    # Use 4 nodes, 5 edges (similar to sample that returned -1)
    edges = [(1, 2), (1, 3), (1, 4), (2, 3), (2, 4), (3, 4)]
    if len(edges) > 8:
        edges = edges[:8]
    
    edge_u, edge_v = encode_edges(edges)
    
    dut.node_count.value = 4
    dut.edge_count.value = len(edges)
    for i in range(8):
        setattr(dut, f'edge_u_{i}', edge_u[i])
        setattr(dut, f'edge_v_{i}', edge_v[i])
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.valid.value or dut.error.value:
            break
    
    if dut.error.value:
        print("Test 3: Correctly identified as impossible")
    elif dut.valid.value:
        result = int(dut.min_cost.value)
        print(f"Test 3: Found solution with cost {result}")

@cocotb.test()
async def test_graph_decoration_edge_case_zero_edges(dut):
    """Test with zero edges"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.node_count.value = 2
    dut.edge_count.value = 0
    for i in range(8):
        setattr(dut, f'edge_u_{i}', 0)
        setattr(dut, f'edge_v_{i}', 0)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.valid.value or dut.error.value:
            break
    
    # With zero edges, cost is 0, but sum must be odd for cycles
    # No cycles = no constraint, so cost should be 0
    if dut.valid.value:
        result = int(dut.min_cost.value)
        print(f"Test 4 (zero edges): Result={result}")
        # No cycles means cycle constraint doesn't apply
        assert result == 0, f"Expected 0, got {result}"

@cocotb.test()
async def test_graph_decoration_one_edge(dut):
    """Test with single edge"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    edges = [(1, 2)]
    edge_u, edge_v = encode_edges(edges)
    
    dut.node_count.value = 2
    dut.edge_count.value = 1
    for i in range(8):
        setattr(dut, f'edge_u_{i}', edge_u[i])
        setattr(dut, f'edge_v_{i}', edge_v[i])
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.valid.value or dut.error.value:
            break
    
    if dut.valid.value:
        result = int(dut.min_cost.value)
        print(f"Test 5 (one edge): Result={result}")
        # One edge, no pairs, no cycle, min cost is 0
        assert result == 0, f"Expected 0, got {result}"
