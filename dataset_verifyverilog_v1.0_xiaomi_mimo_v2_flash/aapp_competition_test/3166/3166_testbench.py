import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 1  # each adjacency entry is 1 bit
N_MAX = 8
K_MAX = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
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

# Helper to pack adjacency matrix
def pack_adj(adj_matrix):
    """adj_matrix is a list of lists of 0/1, size n x n."""
    packed = 0
    n = len(adj_matrix)
    for i in range(n):
        for j in range(n):
            if adj_matrix[i][j]:
                bit_pos = i * 8 + j
                packed |= (1 << bit_pos)
    return packed

# Helper to create s_mask from list of indices
def create_s_mask(s_list, n):
    mask = 0
    for idx in s_list:
        if idx < n:
            mask |= (1 << idx)
    return mask

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_ping_pong(dut):
    """Test the ping_pong module with example cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, k, adj_matrix, s_list, expected_result)
    # expected_result: integer (0-7) or 255 for impossible
    test_cases = [
        (4, 2, [
            [0,0,1,1],
            [1,0,0,1],
            [0,1,0,0],
            [0,0,1,0]
        ], [0,2], 1),
        (4, 2, [
            [0,0,1,1],
            [1,0,0,1],
            [0,1,0,0],
            [0,0,1,0]
        ], [1,2], 255),
        (5, 3, [
            [0,1,1,0,1],
            [0,0,1,1,0],
            [0,0,0,0,1],
            [1,0,1,0,1],
            [0,1,0,0,0]
        ], [0,1,2], 2)
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, k, adj, s_list, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: n={n}, k={k}, S={s_list}, expected={expected}")
        
        # Pack inputs
        adj_packed = pack_adj(adj)
        s_mask = create_s_mask(s_list, n)
        
        # Set inputs
        dut.n.value = n
        dut.k.value = k
        dut.adj.value = adj_packed
        dut.s_mask.value = s_mask
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout waiting for done in test {i+1}")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined in test {i+1}")
        
        result = int(dut.result.value)
        
        if result != expected:
            dut._log.error(f"Test {i+1} failed: expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"Test {i+1} passed")
            passed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# END OF TESTBENCH
# ============================================================================
