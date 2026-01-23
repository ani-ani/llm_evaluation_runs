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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TEST CONFIGURATION
# ============================================================================
K = 4               # Number of initial values
W = 8               # Value width
L = 16              # Index width
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000   # Timeout for waiting for done

# ============================================================================
# HELPER FUNCTIONS FOR THIS DUT
# ============================================================================
async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.query.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_load(dut, a_vals):
    """Pulse start to load initial values a0..a3."""
    # Assign individual a ports
    dut.a0.value = clamp_to_width(a_vals[0], W)
    dut.a1.value = clamp_to_width(a_vals[1], W)
    dut.a2.value = clamp_to_width(a_vals[2], W)
    dut.a3.value = clamp_to_width(a_vals[3], W)
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # Wait for module to be ready (LOADED state)
    # We can wait a few cycles
    for _ in range(2):
        await RisingEdge(dut.clk)

async def perform_query(dut, l, r):
    """Pulse query, wait for done, return result."""
    # Set query inputs
    dut.l.value = clamp_to_width(l, L)
    dut.r.value = clamp_to_width(r, L)
    await RisingEdge(dut.clk)
    dut.query.value = 1
    await RisingEdge(dut.clk)
    dut.query.value = 0
    # Wait for done
    cycles = 0
    while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
        await RisingEdge(dut.clk)
        cycles += 1
        if cycles > MAX_CYCLES:
            raise TestFailure(f"Timeout waiting for done (max {MAX_CYCLES} cycles)")
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    return int(dut.result.value)

# ============================================================================
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================
def compute_expected(a, l, r):
    """
    Compute XOR of x_l..x_r using the period property.
    a: list of K initial values
    Returns XOR as integer.
    """
    # Compute prefix XOR array P[0..K] where P[0]=0, P[i] = XOR_{j=1..i} a[j-1]
    P = [0]
    cur = 0
    for val in a:
        cur ^= val
        P.append(cur)
    M = K + 1
    # P has length M (indices 0..K)
    # For any index n, P(n) = P[n % M] (with P[0]=0)
    # So answer = P[r % M] ^ P[(l-1) % M]
    def get_P(n):
        idx = n % M
        return P[idx]
    ans = get_P(r) ^ get_P(l-1)
    return ans

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_xorbonacci(dut):
    """Test the xorbonacci module with scaled-down parameters."""
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: each is (description, a_vals, list of (l,r) queries)
    # We use the examples from the problem statement.
    test_cases = [
        (
            "Example 1: a=[1,3,5,7]",
            [1, 3, 5, 7],
            [
                (2, 2, 3),   # expected 3
                (2, 5, 1),   # expected 1
                (1, 5, 0),   # expected 0
            ]
        ),
        (
            "Example 2: a=[3,3,4,3,2] -> but K=4, so we take first 4 values [3,3,4,3]",
            [3, 3, 4, 3],
            [
                (1, 2, 0),   # expected 0 (from original example: 0
                (1, 3, 4),   # expected 4 (original: 4)
                (5, 6, 7),   # expected 7 (original: 7)
                (7, 9, 4),   # expected 4 (original: 4)
            ]
        ),
    ]
    
    total_queries = 0
    for desc, a_vals, queries in test_cases:
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test: {desc}")
        dut._log.info(f"{'='*60}")
        
        # Load initial values
        await start_load(dut, a_vals)
        
        for l, r, expected in queries:
            total_queries += 1
            dut._log.info(f"  Query: l={l}, r={r}  -> expected={expected}")
            
            # Perform query
            result = await perform_query(dut, l, r)
            
            if result != expected:
                raise TestFailure(f"Query (l={l}, r={r}): expected {expected}, got {result}")
            else:
                dut._log.info(f"    PASS: got {result}")
    
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"All {total_queries} queries passed.")
    dut._log.info(f"{'='*60}")