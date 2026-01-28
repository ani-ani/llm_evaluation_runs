import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

def pack_adjacency_matrix(adj_matrix, n):
    """Pack adjacency matrix into 16x16 array for Verilog."""
    packed = [0] * 16
    for i in range(n):
        for j in range(n):
            if adj_matrix[i][j]:
                packed[i] |= (1 << j)
    return packed

def create_university_mask(universities, n):
    """Create bitmask from list of university towns."""
    mask = 0
    for u in universities:
        if u < n:
            mask |= (1 << u)
    return mask

# ============================================================================
# BUILD TREE FROM EDGES
# ============================================================================

def build_tree_adjacency(n, edges):
    """Build adjacency matrix from tree edges."""
    adj = [[0] * n for _ in range(n)]
    for u, v in edges:
        if u < n and v < n:
            adj[u][v] = 1
            adj[v][u] = 1
    return adj

# ============================================================================
# REFERENCE IMPLEMENTATION
# ============================================================================

def reference_max_distance(n, k, universities, edges):
    """Reference Python implementation for verification."""
    # Build adjacency list
    adj = [[] for _ in range(n)]
    for u, v in edges:
        if u < n and v < n:
            adj[u].append(v)
            adj[v].append(u)
    
    # BFS to build tree and get order
    parent = [-1] * n
    parent[0] = 0
    queue = [0]
    bfs_order = []
    head = 0
    
    while head < len(queue):
        u = queue[head]
        head += 1
        for v in adj[u]:
            if parent[v] == -1:
                parent[v] = u
                queue.append(v)
                bfs_order.append(v)
    
    # Calculate subtree counts
    subtree_count = [0] * n
    for u in range(n):
        subtree_count[u] = 1 if u in universities else 0
    
    # Process in reverse BFS order
    for i in range(len(bfs_order) - 1, -1, -1):
        u = bfs_order[i]
        if parent[u] != u:
            subtree_count[parent[u]] += subtree_count[u]
    
    # Calculate total distance
    total = 0
    for u in range(1, n):  # Skip root
        if 0 < subtree_count[u] < 2*k:
            total += min(subtree_count[u], 2*k - subtree_count[u])
    
    return total

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_treeland_max_distance(dut):
    """Test the treeland max distance module."""
    
    # Configuration
    CLK_PERIOD_NS = 10
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from problem
    test_cases = [
        # Case 1: n=7, k=2
        {
            'n': 7,
            'k': 2,
            'universities': [0, 4, 5, 1],  # Towns 1,5,6,2 -> 0-indexed: 0,4,5,1
            'edges': [(0,2), (2,1), (3,4), (2,6), (3,2), (3,5)],  # Convert to 0-indexed
            'expected': 6
        },
        # Case 2: n=9, k=3
        {
            'n': 9,
            'k': 3,
            'universities': [2, 1, 0, 5, 4, 8],  # Towns 3,2,1,6,5,9 -> 0-indexed: 2,1,0,5,4,8
            'edges': [(7,8), (2,1), (1,6), (2,3), (6,5), (3,4), (1,0), (1,7)],  # 0-indexed
            'expected': 9
        },
        # Small test: n=2, k=1
        {
            'n': 2,
            'k': 1,
            'universities': [0, 1],
            'edges': [(0, 1)],
            'expected': 1
        },
        # Small test: n=4, k=2
        {
            'n': 4,
            'k': 2,
            'universities': [0, 2, 1, 3],
            'edges': [(0, 1), (3, 2), (0, 3)],
            'expected': 4
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, test in enumerate(test_cases):
        n = test['n']
        k = test['k']
        univ = test['universities']
        edges = test['edges']
        expected = test['expected']
        
        cocotb.log.info(f"Test {i+1}: n={n}, k={k}, expected={expected}")
        
        # Build adjacency matrix
        adj_matrix = build_tree_adjacency(n, edges)
        packed_adj = pack_adjacency_matrix(adj_matrix, n)
        university_mask = create_university_mask(univ, n)
        
        # Set inputs
        dut.n.value = n
        dut.k.value = k
        dut.universities.value = university_mask
        
        # Set adjacency matrix (element by element)
        for row in range(16):
            dut.adj[row].value = packed_adj[row] if row < n else 0
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        timeout_cycles = 500
        for _ in range(timeout_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined")
        
        result = int(dut.result.value)
        
        # Verify
        if result != expected:
            # Also verify with reference
            ref_result = reference_max_distance(n, k, univ, edges)
            if result != ref_result:
                cocotb.log.error(f"Test {i+1}: FAIL - Expected {expected}, got {result}, reference {ref_result}")
                failed += 1
            else:
                cocotb.log.info(f"Test {i+1}: PASS - Result {result} matches reference")
                passed += 1
        else:
            cocotb.log.info(f"Test {i+1}: PASS - Result {result}")
            passed += 1
        
        # Wait for idle
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
