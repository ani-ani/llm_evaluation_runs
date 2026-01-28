import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================

MAX_N = 8
DATA_WIDTH = 16
RESULT_WIDTH = 64
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_magic_path(dut):
    """Test the min_magic_path module with two test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper to pack adjacency matrix
    def pack_adjacency(adj_matrix, max_n):
        packed = 0
        for i in range(max_n):
            for j in range(max_n):
                if adj_matrix[i][j]:
                    packed |= 1 << (i * max_n + j)
        return packed
    
    # Helper to pack magic values
    def pack_magic(magic_list, max_n, data_width):
        packed = 0
        for i, val in enumerate(magic_list):
            packed |= (val & ((1 << data_width) - 1)) << (i * data_width)
        return packed
    
    # Helper to compute expected minimal magic
    def compute_expected(N, edges, magics):
        # Build adjacency matrix and compute all paths
        adj = [[0]*N for _ in range(N)]
        for u, v in edges:
            adj[u][v] = 1
            adj[v][u] = 1
        # BFS to get parent and depth from root 0
        parent = [0]*N
        depth = [0]*N
        visited = [False]*N
        from collections import deque
        q = deque([0])
        visited[0] = True
        parent[0] = 0
        depth[0] = 0
        while q:
            u = q.popleft()
            for v in range(N):
                if adj[u][v] and not visited[v]:
                    visited[v] = True
                    parent[v] = u
                    depth[v] = depth[u] + 1
                    q.append(v)
        # Function to compute product and length of path i-j
        def path_product_length(i, j):
            prod = 1
            length = 0
            u, v = i, j
            # Move u up to depth of v
            while depth[u] > depth[v]:
                prod *= magics[u]
                length += 1
                u = parent[u]
            # Move v up to depth of u
            while depth[v] > depth[u]:
                prod *= magics[v]
                length += 1
                v = parent[v]
            # Move both up until they meet
            while u != v:
                prod *= magics[u]
                length += 1
                u = parent[u]
                prod *= magics[v]
                length += 1
                v = parent[v]
            # Add LCA
            prod *= magics[u]
            length += 1
            return prod, length
        # Enumerate all pairs (i,j) with i <= j
        best_prod = None
        best_len = None
        for i in range(N):
            for j in range(i, N):
                prod, length = path_product_length(i, j)
                if best_prod is None:
                    best_prod = prod
                    best_len = length
                else:
                    # Compare fractions: prod/length < best_prod/best_len ?
                    if prod * best_len < best_prod * length:
                        best_prod = prod
                        best_len = length
        # Reduce fraction
        g = math.gcd(best_prod, best_len)
        return best_prod // g, best_len // g
    
    # Test cases
    test_cases = [
        {
            "N": 2,
            "edges": [(0, 1)],
            "magics": [3, 4],
            "expected": (3, 1)
        },
        {
            "N": 5,
            "edges": [(0, 1), (1, 3), (0, 2), (4, 1)],
            "magics": [2, 1, 1, 1, 3],
            "expected": (1, 2)
        }
    ]
    
    for idx, tc in enumerate(test_cases):
        dut._log.info(f"Test case {idx+1}: N={tc['N']}")
        
        # Pack inputs
        adj_packed = pack_adjacency(
            [[0]*MAX_N for _ in range(MAX_N)],  # zero matrix
            MAX_N
        )
        # Fill actual edges
        for u, v in tc['edges']:
            adj_packed |= 1 << (u * MAX_N + v)
            adj_packed |= 1 << (v * MAX_N + u)
        magic_packed = pack_magic(tc['magics'], MAX_N, DATA_WIDTH)
        
        # Assign to DUT
        dut.N.value = tc['N']
        dut.adj_flat.value = adj_packed
        dut.magic_flat.value = magic_packed
        
        # Pulse start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while cycles < MAX_CYCLES:
            await RisingEdge(dut.clk)
            cycles += 1
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Read result
        if not (is_value_defined(dut.result_numer.value) and is_value_defined(dut.result_denom.value)):
            raise TestFailure("Result signals are undefined")
        
        result_numer = int(dut.result_numer.value)
        result_denom = int(dut.result_denom.value)
        
        # Expected
        exp_numer, exp_denom = tc['expected']
        
        # Compare
        if result_numer != exp_numer or result_denom != exp_denom:
            raise TestFailure(
                f"Test {idx+1} failed: expected {exp_numer}/{exp_denom}, got {result_numer}/{result_denom}"
            )
        
        dut._log.info(f"  PASS: {result_numer}/{result_denom}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")
