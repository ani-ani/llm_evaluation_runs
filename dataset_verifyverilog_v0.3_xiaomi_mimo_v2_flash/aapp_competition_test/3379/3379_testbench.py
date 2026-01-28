import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# COMPUTE EXPECTED RESULT (Python reference)
# ============================================================================
def compute_width(adj):
    n = len(adj)
    if n == 0:
        return 0
    # Compute reachability using Floyd-Warshall
    reach = [row[:] for row in adj]  # copy
    for k in range(n):
        for i in range(n):
            for j in range(n):
                if reach[i][k] and reach[k][j]:
                    reach[i][j] = 1
    # Identify nodes in cycles
    in_cycle = [False] * n
    for i in range(n):
        for j in range(n):
            if i != j and reach[i][j] and reach[j][i]:
                in_cycle[i] = True
                break
    # Propagate bad nodes: nodes reachable from any cycle node
    bad = set()
    for i in range(n):
        if in_cycle[i]:
            bad.add(i)
    # Expand to all nodes reachable from any bad node
    changed = True
    while changed:
        changed = False
        for i in range(n):
            if i in bad:
                for j in range(n):
                    if j not in bad and reach[i][j]:
                        bad.add(j)
                        changed = True
    # Good nodes
    good = [i for i in range(n) if i not in bad]
    if not good:
        return 0
    m = len(good)
    # Build reachability for good nodes
    good_reach = [[0]*m for _ in range(m)]
    for i_idx, i in enumerate(good):
        for j_idx, j in enumerate(good):
            if i != j and reach[i][j]:
                good_reach[i_idx][j_idx] = 1
    # Enumerate all subsets of good nodes
    max_size = 0
    # Since m <= 8, we can iterate over all subsets (0..2^m-1)
    for mask in range(1 << m):
        subset = []
        for k in range(m):
            if (mask >> k) & 1:
                subset.append(k)
        # Check if antichain
        ok = True
        for a_idx in range(len(subset)):
            for b_idx in range(a_idx+1, len(subset)):
                u = subset[a_idx]
                v = subset[b_idx]
                if good_reach[u][v] or good_reach[v][u]:
                    ok = False
                    break
            if not ok:
                break
        if ok:
            size = len(subset)
            if size > max_size:
                max_size = size
    return max_size

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_topological_width(dut):
    """Test the topological_width module with various graphs."""
    
    # Configure based on your design
    N = 4  # Must match the parameter N in the DUT
    GRAPH_WIDTH = N * N
    CLK_PERIOD = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: adjacency matrices (list of lists of 0/1)
    test_cases = [
        # Case 1: Chain 0->1->2->3
        ([[0,1,0,0],
          [0,0,1,0],
          [0,0,0,1],
          [0,0,0,0]], "Chain 0->1->2->3"),
        
        # Case 2: No edges (all zeros) - antichain size = 4
        ([[0,0,0,0],
          [0,0,0,0],
          [0,0,0,0],
          [0,0,0,0]], "No edges"),
        
        # Case 3: DAG with antichain size 2 (edges: 0->3, 1->2, 1->3, 2->3)
        ([[0,0,0,1],
          [0,0,1,1],
          [0,0,0,1],
          [0,0,0,0]], "DAG with antichain size 2"),
        
        # Case 4: Graph with a cycle (0->1,1->2,2->0) and isolated node 3
        ([[0,1,0,0],
          [0,0,1,0],
          [1,0,0,0],
          [0,0,0,0]], "Cycle (0,1,2) plus isolated node 3"),
        
        # Case 5: Graph with a cycle and a node reachable from cycle (0->1,1->2,2->0, 0->3)
        ([[0,1,0,1],
          [0,0,1,0],
          [1,0,0,0],
          [0,0,0,0]], "Cycle with edge to node 3"),
        
        # Case 6: More complex DAG (add more if needed)
        ([[0,1,1,0],
          [0,0,0,1],
          [0,0,0,1],
          [0,0,0,0]], "DAG with antichain size?"),
    ]
    
    for i, (adj, desc) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {desc}")
        
        # Compute expected result
        expected = compute_width(adj)
        dut._log.info(f"  Expected: {expected}")
        
        # Pack adjacency matrix into graph_packed
        packed = 0
        for r in range(N):
            for c in range(N):
                if adj[r][c]:
                    pos = r * N + c
                    packed |= (1 << pos)
        
        # Assign graph_packed
        dut.graph_packed.value = packed
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        actual = int(dut.result.value)
        
        if actual != expected:
            raise TestFailure(f"Test {i+1}: expected {expected}, got {actual}")
        
        dut._log.info(f"  PASS: result = {actual}")
    
    dut._log.info("All tests passed!")