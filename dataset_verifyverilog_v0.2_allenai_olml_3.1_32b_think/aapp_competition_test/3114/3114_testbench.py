import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

class GraphTester:
    def __init__(self, dut):
        self.dut = dut
        self.log = dut._log
        
    def build_graph(self, edges):
        """Build adjacency list for connectivity check"""
        adj = {}
        for u, v in edges:
            if u not in adj: adj[u] = []
            if v not in adj: adj[v] = []
            adj[u].append(v)
            adj[v].append(u)
        return adj
    
    def dfs_check(self, adj, start_node, n_nodes):
        """Returns set of reachable nodes from start_node"""
        visited = set()
        stack = [start_node]
        while stack:
            node = stack.pop()
            if node in visited:
                continue
            visited.add(node)
            if node in adj:
                for neighbor in adj[node]:
                    if neighbor not in visited:
                        stack.append(neighbor)
        return visited
    
    def has_bridge(self, edges, n_nodes):
        """Check if graph has any bridges"""
        for i in range(len(edges)):
            # Remove edge i and check connectivity
            adj = self.build_graph(edges[:i] + edges[i+1:])
            if n_nodes == 0:
                return False
            # Start from first edge's endpoint
            start = edges[0][0] if edges else 1
            reachable = self.dfs_check(adj, start, n_nodes)
            if len(reachable) != n_nodes:
                return True
        return False
    
    def python_reference(self, n_nodes, n_edges, edges):
        """Python reference implementation"""
        if n_nodes <= 1:
            return True, edges
        if self.has_bridge(edges, n_nodes):
            return False, []
        return True, edges

@cocotb.test()
async def test_graph_orientability(dut):
    """Test graph orientability detection"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_nodes.value = 0
    dut.n_edges.value = 0
    for i in range(6):
        dut.edge_u[i].value = 0
        dut.edge_v[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (3, 3, [(1,2), (2,3), (1,3)]),  # Triangle - no bridge
        (4, 3, [(1,2), (1,3), (1,4)]),  # Star with center 1 - bridges
        (4, 5, [(1,2), (2,3), (4,3), (1,4), (2,4)]),  # Dense - no bridge
        (2, 1, [(1,2)]),  # Single edge - bridge
        (1, 0, []),  # Single node - possible
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (n, m, edges) in enumerate(test_cases):
        dut._log.info(f"Test case {idx+1}: N={n}, M={m}, Edges={edges}")
        
        # Load inputs
        dut.n_nodes.value = n
        dut.n_edges.value = m
        for i in range(6):
            if i < m:
                dut.edge_u[i].value = edges[i][0]
                dut.edge_v[i].value = edges[i][1]
            else:
                dut.edge_u[i].value = 0
                dut.edge_v[i].value = 0
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 200:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 200:
            raise TestFailure(f"Test {idx+1} timed out")
        
        # Get results
        possible = bool(dut.possible.value)
        valid = bool(dut.valid.value)
        
        # Python reference
        ref_possible, ref_edges = self.python_reference(n, m, edges)
        
        dut._log.info(f"Result: possible={possible}, valid={valid}")
        dut._log.info(f"Reference: possible={ref_possible}")
        
        if not valid:
            raise TestFailure(f"Test {idx+1}: valid signal not high")
        
        if possible != ref_possible:
            raise TestFailure(
                f"Test {idx+1}: Expected possible={ref_possible}, got {possible}"
            )
        
        if possible and m > 0:
            # Check output edges are valid
            out_edges = []
            for i in range(m):
                u = int(dut.out_u[i].value)
                v = int(dut.out_v[i].value)
                if u != 0 and v != 0:
                    out_edges.append((u, v))
            dut._log.info(f"Output edges: {out_edges}")
        
        passed += 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
=== Summary: {passed}/{total} tests passed ===")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(30, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: Single node
    dut.n_nodes.value = 1
    dut.n_edges.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.possible.value == 1, "Single node should be possible"
    assert dut.valid.value == 1, "Output should be valid"
    
    # Test: Two nodes, one edge (bridge)
    dut.n_nodes.value = 2
    dut.n_edges.value = 1
    dut.edge_u[0].value = 1
    dut.edge_v[0].value = 2
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.possible.value == 0, "Two nodes, one edge should be impossible"
    
    dut._log.info("Edge cases passed")
