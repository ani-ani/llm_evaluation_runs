import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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
# HELPER FUNCTIONS FOR TESTBENCH
# ============================================================================

def pack_adj(adj_list, n):
    """Pack adjacency matrix for 4 islands into 16-bit vector."""
    packed = 0
    for i in range(4):
        for j in range(4):
            if i < n and j < n:
                bit = adj_list[i][j]
            else:
                bit = 0
            packed |= (bit << (i*4 + j))
    return packed

def pack_L(L_matrix, n):
    """Pack L matrix (4x4) into 64-bit vector."""
    packed = 0
    for i in range(4):
        for j in range(4):
            if i < n and j < n:
                val = L_matrix[i][j]
            else:
                val = 0
            packed |= (val << (16*(i*4 + j)))
    return packed

def is_strongly_connected_py(adj, n):
    """Check strong connectivity in Python."""
    # Use Floyd-Warshall to compute reachability
    reach = [row[:] for row in adj]
    for k in range(n):
        for i in range(n):
            for j in range(n):
                if reach[i][k] and reach[k][j]:
                    reach[i][j] = 1
    for i in range(n):
        for j in range(n):
            if reach[i][j] == 0:
                return False
    return True

def compute_expected(n, adj, L):
    """Compute expected minimal tunnel length."""
    if is_strongly_connected_py(adj, n):
        return 0
    min_len = 65535  # sentinel for impossible
    # Try all pairs i < j
    for i in range(n):
        for j in range(i+1, n):
            # Create new adjacency with added bidirectional edges
            new_adj = [row[:] for row in adj]
            new_adj[i][j] = 1
            new_adj[j][i] = 1
            if is_strongly_connected_py(new_adj, n):
                if L[i][j] < min_len:
                    min_len = L[i][j]
    return min_len

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_island_courier(dut):
    """Test the island_courier module."""
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    test_cases = []
    
    # Test case 1: n=2, graph 0->1, no 1->0, L[0][1]=500
    n = 2
    adj = [[1,1],[0,1]]  # self-loops: 1, edge 0->1
    L = [[0,500],[500,0]]
    expected = 500
    test_cases.append((n, adj, L, expected, "n=2, add edge"))
    
    # Test case 2: n=3, chain 0->1->2, L[2][0]=700
    n = 3
    adj = [[1,1,0],[0,1,1],[0,0,1]]
    L = [[0,100,200],[100,0,300],[700,300,0]]
    expected = 700
    test_cases.append((n, adj, L, expected, "n=3, add back edge"))
    
    # Test case 3: n=2, no edges between, L[0][1]=300
    n = 2
    adj = [[1,0],[0,1]]
    L = [[0,300],[300,0]]
    expected = 300
    test_cases.append((n, adj, L, expected, "n=2, isolated islands"))
    
    # Test case 4: n=4, strongly connected already, L any
    n = 4
    adj = [[1,1,1,1],[1,1,1,1],[1,1,1,1],[1,1,1,1]]  # all connected
    L = [[0]*4 for _ in range(4)]  # not used
    expected = 0
    test_cases.append((n, adj, L, expected, "n=4, already strongly connected"))
    
    # Test case 5: n=2, no edges, but adding tunnel still not enough? Actually adding tunnel makes it connected.
    # Already covered.
    
    # Run tests
    for idx, (n_val, adj_mat, L_mat, expected, desc) in enumerate(test_cases):
        dut._log.info(f"Running test {idx+1}: {desc}")
        
        # Pack inputs
        n_bits = n_val - 1  # 1->0, 2->1, 3->2, 4->3
        adj_packed = pack_adj(adj_mat, n_val)
        L_packed = pack_L(L_mat, n_val)
        
        # Set inputs
        dut.n.value = n_bits
        dut.adj.value = adj_packed
        dut.L.value = L_packed
        
        # Pulse start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > 1000:
                raise TestFailure(f"Timeout waiting for done in test {idx+1}")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined in test {idx+1}")
        result = int(dut.result.value)
        
        # Compare
        if expected == "impossible":
            if result != 65535:
                raise TestFailure(f"Test {idx+1}: expected impossible, got {result}")
        else:
            if result != expected:
                raise TestFailure(f"Test {idx+1}: expected {expected}, got {result}")
        
        dut._log.info(f"Test {idx+1} PASSED: result = {result}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")
