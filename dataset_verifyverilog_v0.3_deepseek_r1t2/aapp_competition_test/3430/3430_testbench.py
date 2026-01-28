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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# TEST HELPERS
# ============================================================================

def build_adjacency_matrix(edges, n, max_nodes=8):
    """Build adjacency matrix rows from list of edges.
    edges: list of (u,v) with 1-indexed nodes.
    Returns a list of max_nodes integers, each 8-bit row.
    """
    adj = [0] * max_nodes
    for u, v in edges:
        u0 = u - 1  # convert to 0-indexed
        v0 = v - 1
        if u0 < max_nodes and v0 < max_nodes:
            adj[u0] |= (1 << v0)
            adj[v0] |= (1 << u0)
    # Ensure rows beyond n are zero
    for i in range(n, max_nodes):
        adj[i] = 0
    return adj

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_transmission_cost(dut):
    """Test the min_transmission_cost module with sample inputs."""
    
    # Detect if module has clock (sequential) - we assume combinational
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock if needed
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        # Reset sequence
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Define test cases
    test_cases = [
        # (N, edges_A, M, edges_B, expected_min_cost)
        (3, [(1,2), (2,3)], 4, [(1,2), (1,3), (1,4)], 96),
        (7, [(1,2), (2,3), (2,4), (4,5), (5,6), (5,7)], 5, [(1,2), (1,3), (1,4), (1,5)], 551),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (N, edges_A, M, edges_B, expected) in enumerate(test_cases):
        dut._log.info(f"\nTest {idx+1}: N={N}, M={M}")
        
        # Build adjacency matrices
        adj_A = build_adjacency_matrix(edges_A, N)
        adj_B = build_adjacency_matrix(edges_B, M)
        
        # Assign N and M
        dut.N.value = N
        dut.M.value = M
        
        # Assign adjacency rows for A
        for i in range(8):
            if has_signal(dut, f'adj_A_{i}'):
                getattr(dut, f'adj_A_{i}').value = adj_A[i]
            else:
                # Fallback to indexed array if present
                if has_signal(dut, 'adj_A'):
                    dut.adj_A[i].value = adj_A[i]
        
        # Assign adjacency rows for B
        for i in range(8):
            if has_signal(dut, f'adj_B_{i}'):
                getattr(dut, f'adj_B_{i}').value = adj_B[i]
            else:
                if has_signal(dut, 'adj_B'):
                    dut.adj_B[i].value = adj_B[i]
        
        # Wait for combinational propagation
        if is_sequential:
            await RisingEdge(dut.clk)
        else:
            await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.min_cost.value):
            dut._log.error(f"  FAIL: min_cost is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.min_cost.value)
        
        if result != expected:
            dut._log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
