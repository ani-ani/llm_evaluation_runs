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
# CONFIGURATION
# ============================================================================

N = 8                  # Number of nodes
DATA_WIDTH = 16        # Result width
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000     # Timeout for computation

# ============================================================================
# HELPER: Compute reachability matrix from edges (for small N)
# ============================================================================

def compute_reachability(n, edges):
    """Compute reachability matrix using Floyd-Warshall for small n."""
    reach = [[0]*n for _ in range(n)]
    # Self-reach
    for i in range(n):
        reach[i][i] = 1
    # Direct edges
    for (u, v) in edges:
        reach[u][v] = 1
    # Floyd-Warshall
    for k in range(n):
        for i in range(n):
            for j in range(n):
                if reach[i][k] and reach[k][j]:
                    reach[i][j] = 1
    return reach

def pack_reachability(reach):
    """Pack 8x8 reachability matrix into 64-bit integer."""
    packed = 0
    for i in range(8):
        for j in range(8):
            if reach[i][j]:
                idx = i*8 + j
                packed |= (1 << idx)
    return packed

def pack_targets(targets):
    """Pack list of 0-indexed targets (max 8) into 24-bit vector."""
    packed = 0
    for i, t in enumerate(targets):
        packed |= (t & 0x7) << (3*i)
    return packed

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_ski_resort(dut):
    """Test the ski_resort module with sample queries."""
    
    # Detect interface
    has_clk = has_signal(dut, 'clk')
    if not has_clk:
        raise TestFailure("DUT must have 'clk' signal")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    # Each test case: (graph_edges, query_list)
    # query_list: (k, a, [targets]) where targets are 1-indexed
    test_cases = [
        # Sample Input 1 (scaled to 8 nodes, but we use original 4-node case scaled to 8? We'll use actual 4-node with n=4 mapped to 0..3)
        # Let's create a smaller test: n=4, edges as in sample, then map to 0..3
        {
            'edges': [(0,1), (0,2), (1,3), (2,3)],  # 0: area1, 1: area2, 2: area3, 3: area4
            'queries': [
                (1, 1, [3]),   # k=1, a=1, target=4 (index 3)
                (2, 1, [3]),   # k=2, a=1, target=4
                (1, 1, [2]),   # k=1, a=1, target=3 (index 2)
                (2, 2, [2,3]), # k=2, a=2, targets=3,4 (indices 2,3)
            ],
            'expected': [2, 0, 2, 1]
        },
        # Another test with more nodes
        {
            'edges': [(0,1), (1,2), (0,2), (2,5), (5,7), (1,3), (1,4), (3,6), (4,6), (6,7)],
            # nodes: 0,1,2,3,4,5,6,7 (8 nodes)
            'queries': [
                (2, 3, [3,4,5]),  # k=2, a=3, targets 4,5,6 (indices 3,4,5) -> expected 0
                (2, 2, [5,7]),    # k=2, a=2, targets 6,8 (indices 5,7) -> expected 0
                (1, 1, [5]),      # k=1, a=1, target 6 (index 5) -> expected 3
                (1, 1, [7]),      # k=1, a=1, target 8 (index 7) -> expected 2
            ],
            'expected': [0, 0, 3, 2]
        }
    ]
    
    total_tests = 0
    passed_tests = 0
    
    for tc_idx, test_case in enumerate(test_cases):
        edges = test_case['edges']
        queries = test_case['queries']
        expected = test_case['expected']
        
        # Compute reachability for this graph
        reach = compute_reachability(N, edges)
        reach_packed = pack_reachability(reach)
        
        dut._log.info(f"Test case {tc_idx+1}:")
        dut._log.info(f"  Graph edges: {edges}")
        dut._log.info(f"  Reachability packed: 0x{reach_packed:016X}")
        
        for q_idx, (k, a, targets_1idx) in enumerate(queries):
            total_tests += 1
            # Convert targets to 0-indexed
            targets_0idx = [t-1 for t in targets_1idx]
            
            dut._log.info(f"  Query {q_idx+1}: k={k}, a={a}, targets={targets_1idx}")
            
            # Pack inputs
            reach_val = reach_packed
            k_val = k
            a_val = a
            t_val = pack_targets(targets_0idx)
            
            # Assign to DUT
            dut.reach.value = reach_val
            dut.k_in.value = k_val
            dut.a_in.value = a_val
            dut.t_in.value = t_val
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done with timeout
            cycles = 0
            while not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
                await RisingEdge(dut.clk)
                cycles += 1
                if cycles > MAX_CYCLES:
                    raise TestFailure(f"Timeout waiting for done after {MAX_CYCLES} cycles")
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result_val = int(dut.result.value)
            expected_val = expected[q_idx]
            
            if result_val != expected_val:
                raise TestFailure(f"Query {q_idx+1}: expected {expected_val}, got {result_val}")
            
            dut._log.info(f"    PASS: result = {result_val}")
            passed_tests += 1
            
            # Wait a few cycles before next query
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
    
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"Total: {passed_tests}/{total_tests} tests passed")
    
    if passed_tests != total_tests:
        raise TestFailure(f"{total_tests - passed_tests} tests failed")
