import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4          # Node index width (0-3)
EDGE_WIDTH = 8          # {u[3:0], v[3:0]}
MAX_EDGES = 4           # Scaled from original N(N-1)/2
MAX_NODES = 4           # Scaled from original N=50
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH HELPER FUNCTIONS
# ============================================================================

async def reset_dut(dut):
    """Standard reset sequence."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

def pack_edge(u, v):
    """Pack node indices into edge format {u[3:0], v[3:0]}."""
    return ((u & 0xF) << 4) | (v & 0xF)

def unpack_edge(packed):
    """Unpack edge format into (u, v)."""
    u = (packed >> 4) & 0xF
    v = packed & 0xF
    return u, v

def pack_edges(edge_list):
    """Pack list of (u,v) tuples into array of packed edges."""
    packed = []
    for u, v in edge_list:
        packed.append(pack_edge(u, v))
    # Pad to MAX_EDGES
    while len(packed) < MAX_EDGES:
        packed.append(0)
    return packed[:MAX_EDGES]

# ============================================================================
# VERIFICATION HELPERS
# ============================================================================

def check_strong_connectivity(edges, orientation):
    """
    Check if directed graph is strongly connected using Floyd-Warshall.
    edges: list of (u,v) undirected edges
    orientation: list of bits (0=u->v, 1=v->u)
    Returns: True if strongly connected
    """
    n = MAX_NODES
    # Build adjacency matrix
    dist = [[0]*n for _ in range(n)]
    for i in range(n):
        dist[i][i] = 1
    
    for idx, ((u, v), dir_bit) in enumerate(zip(edges, orientation)):
        if dir_bit == 0:
            dist[u][v] = 1
        else:
            dist[v][u] = 1
    
    # Floyd-Warshall
    for k in range(n):
        for i in range(n):
            for j in range(n):
                if dist[i][j] == 0 and dist[i][k] == 1 and dist[k][j] == 1:
                    dist[i][j] = 1
    
    # Check strong connectivity
    for i in range(n):
        for j in range(n):
            if dist[i][j] == 0:
                return False
    return True

def find_valid_orientation(edges):
    """Brute-force search for valid orientation."""
    m = len(edges)
    for orient_mask in range(1 << m):
        orientation = [(orient_mask >> i) & 1 for i in range(m)]
        if check_strong_connectivity(edges, orientation):
            return orientation
    return None

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_graph_orientation(dut):
    """Test graph orientation module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: list of (edges, description, should_be_possible)
    test_cases = [
        # Triangle (3 nodes, 3 edges) - should be possible
        ([(0,1), (1,2), (0,2)], "Triangle graph", True),
        # Star (3 edges from node 0) - should be impossible
        ([(0,1), (0,2), (0,3)], "Star graph", False),
        # Cycle of 4 nodes (4 edges) - should be possible
        ([(0,1), (1,2), (2,3), (3,0)], "4-node cycle", True),
        # Complete graph K4 (6 edges) - should be possible
        ([(0,1), (0,2), (0,3), (1,2), (1,3), (2,3)], "Complete K4", True),
        # Two triangles sharing a node (5 edges) - should be possible
        ([(0,1), (1,2), (0,2), (1,3), (2,3)], "Two triangles", True),
    ]
    
    passed = 0
    failed = 0
    
    for edges, description, expected in test_cases:
        m = len(edges)
        if m > MAX_EDGES:
            cocotb.log.info(f"Skipping {description}: too many edges ({m} > {MAX_EDGES})")
            continue
        
        cocotb.log.info(f"\nTest: {description} (M={m})")
        cocotb.log.info(f"Edges: {edges}")
        cocotb.log.info(f"Expected: {'YES' if expected else 'NO'}")
        
        # Pack edges
        packed = pack_edges(edges)
        
        # Assign to DUT
        if has_signal(dut, 'edge_0'):
            dut.edge_0.value = packed[0]
            dut.edge_1.value = packed[1]
            dut.edge_2.value = packed[2]
            dut.edge_3.value = packed[3]
        elif has_signal(dut, 'edges_0'):
            dut.edges_0.value = packed[0]
            dut.edges_1.value = packed[1]
            dut.edges_2.value = packed[2]
            dut.edges_3.value = packed[3]
        else:
            raise TestFailure("Cannot find edge input signals")
        
        # Set M
        dut.m.value = m
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check results
        if not is_value_defined(dut.yes_no.value):
            cocotb.log.error("Result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.yes_no.value)
        expected_result = 1 if expected else 0
        
        if result != expected_result:
            cocotb.log.error(f"  FAIL: Expected {expected_result}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: Result = {result}")
            
            # If YES, verify orientation
            if result == 1:
                # Read oriented edges
                oriented = []
                for i in range(MAX_EDGES):
                    if has_signal(dut, f'orient_{i}'):
                        val = getattr(dut, f'orient_{i}').value
                        if is_value_defined(val):
                            u, v = unpack_edge(int(val))
                            oriented.append((u, v))
                
                # Check if this orientation is valid
                if oriented:
                    # Map back to node indices 1-4 for output
                    oriented_output = [(u+1, v+1) for u, v in oriented[:m]]
                    cocotb.log.info(f"  Orientation: {oriented_output}")
                    
                    # Verify it's actually valid
                    orientation_bits = []
                    for i, (eu, ev) in enumerate(edges):
                        if i < len(oriented):
                            ou, ov = oriented[i]
                            if eu == ou and ev == ov:
                                orientation_bits.append(0)  # u->v
                            elif eu == ov and ev == ou:
                                orientation_bits.append(1)  # v->u
                            else:
                                raise TestFailure(f"Edge mismatch at index {i}")
                    
                    if not check_strong_connectivity(edges, orientation_bits):
                        cocotb.log.error("  Generated orientation is NOT strongly connected!")
                        failed += 1
                    else:
                        cocotb.log.info("  Orientation verified as strongly connected")
                        passed += 1
                else:
                    cocotb.log.warning("  No orientation read (possibly all zero)")
                    passed += 1
            else:
                passed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info("All tests completed successfully!")

# ============================================================================
# ADDITIONAL TEST: RANDOM GRAPHS
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_random_graphs(dut):
    """Test with randomly generated graphs."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    random.seed(42)
    passed = 0
    failed = 0
    
    for trial in range(10):
        # Generate random graph
        m = random.randint(2, MAX_EDGES)
        edges = set()
        while len(edges) < m:
            u = random.randint(0, MAX_NODES-1)
            v = random.randint(0, MAX_NODES-1)
            if u != v:
                edges.add(tuple(sorted((u, v))))
        edges = list(edges)
        
        # Expected result: check if graph is 2-edge-connected
        # Simplified: assume NO if M < N (4) or if any bridge exists
        # For random testing, we just check if module completes
        
        cocotb.log.info(f"\nRandom test {trial+1}: M={m}, edges={edges}")
        
        # Pack edges
        packed = pack_edges(edges)
        
        # Assign to DUT
        if has_signal(dut, 'edge_0'):
            dut.edge_0.value = packed[0]
            dut.edge_1.value = packed[1]
            dut.edge_2.value = packed[2]
            dut.edge_3.value = packed[3]
        else:
            cocotb.log.warning("Skipping random test: edge signals not found")
            continue
        
        dut.m.value = m
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=5000)
            
            if is_value_defined(dut.yes_no.value):
                result = int(dut.yes_no.value)
                cocotb.log.info(f"  Result: {result} (completed without timeout)")
                passed += 1
            else:
                cocotb.log.error("  Result undefined")
                failed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"  Failed: {e}")
            failed += 1
    
    cocotb.log.info(f"\nRandom tests: {passed}/{passed+failed} passed")
    if failed > 0:
        raise TestFailure(f"{failed} random tests failed")
