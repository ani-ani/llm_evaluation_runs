import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
FRAC_BITS = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
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
# FIXED-POINT CONVERSION
# ============================================================================

def float_to_fixed(f):
    """Convert float to Q16.16 fixed-point integer."""
    return int(f * (1 << FRAC_BITS))

def fixed_to_float(fixed):
    """Convert Q16.16 fixed-point integer to float."""
    return fixed / (1 << FRAC_BITS)

# ============================================================================
# EXPECTED PROBABILITY COMPUTATION (Python reference)
# ============================================================================

def compute_expected(N, edges, max_k):
    """Compute maximum survival probabilities for k=0..max_k."""
    # dp[node][k] = max probability to reach node with exactly k walks
    dp = [[0.0] * (max_k + 1) for _ in range(N)]
    dp[0][0] = 1.0
    
    # Build ski and walk adjacency
    ski = [[0.0] * N for _ in range(N)]
    walk = [[False] * N for _ in range(N)]
    for a, b, w in edges:
        if a > b:
            a, b = b, a
        ski[a][b] = 1.0 - w
        walk[a][b] = True
        walk[b][a] = True
    
    # DP for each k
    for k in range(max_k + 1):
        # Ski propagation (DAG order)
        for i in range(N):
            for j in range(i + 1, N):
                if ski[i][j] > 0 and dp[i][k] > 0:
                    cand = dp[i][k] * ski[i][j]
                    if cand > dp[j][k]:
                        dp[j][k] = cand
        # Walk propagation to next k
        if k < max_k:
            for i in range(N):
                for j in range(N):
                    if walk[i][j] and dp[j][k] > 0:
                        if dp[j][k] > dp[i][k + 1]:
                            dp[i][k + 1] = dp[j][k]
    
    # Best probabilities (at most k walks)
    best = [0.0] * (max_k + 1)
    for k in range(max_k + 1):
        best[k] = max(dp[N - 1][j] for j in range(k + 1))
    return best

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_ski_probability(dut):
    """Test the ski_probability module with various graphs."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        {
            "name": "Example 1: 2 nodes, edge 0-1 w=0.5",
            "edges": [(0, 1, 0.5)],
            "expected": [0.5, 1.0, 1.0, 1.0]
        },
        {
            "name": "Example 2: 2 nodes, edge 0-1 w=0.25",
            "edges": [(0, 1, 0.25)],
            "expected": [0.75, 1.0, 1.0, 1.0]
        },
        {
            "name": "3 nodes, edges 0-1 w=0.2, 1-2 w=0.3",
            "edges": [(0, 1, 0.2), (1, 2, 0.3)],
            "expected": [0.56, 0.8, 1.0, 1.0]
        },
    ]
    
    for tc in test_cases:
        dut._log.info(f"Running {tc['name']}")
        
        # Initialize all graph signals to zero
        for ski_sig in ['ski_prob_01', 'ski_prob_02', 'ski_prob_03', 
                        'ski_prob_12', 'ski_prob_13', 'ski_prob_23']:
            getattr(dut, ski_sig).value = 0
        for walk_sig in ['walk_edge_01', 'walk_edge_02', 'walk_edge_03', 
                         'walk_edge_12', 'walk_edge_13', 'walk_edge_23']:
            getattr(dut, walk_sig).value = 0
        
        # Set edges
        for a, b, w in tc['edges']:
            if a > b:
                a, b = b, a
            surv = 1.0 - w
            fixed_surv = float_to_fixed(surv)
            
            if a == 0 and b == 1:
                dut.ski_prob_01.value = fixed_surv
                dut.walk_edge_01.value = 1
            elif a == 0 and b == 2:
                dut.ski_prob_02.value = fixed_surv
                dut.walk_edge_02.value = 1
            elif a == 0 and b == 3:
                dut.ski_prob_03.value = fixed_surv
                dut.walk_edge_03.value = 1
            elif a == 1 and b == 2:
                dut.ski_prob_12.value = fixed_surv
                dut.walk_edge_12.value = 1
            elif a == 1 and b == 3:
                dut.ski_prob_13.value = fixed_surv
                dut.walk_edge_13.value = 1
            elif a == 2 and b == 3:
                dut.ski_prob_23.value = fixed_surv
                dut.walk_edge_23.value = 1
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        cycles = 0
        while cycles < MAX_CYCLES:
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
            cycles += 1
        else:
            raise TestFailure(f"Timeout waiting for done in {tc['name']}")
        
        # Read outputs
        prob_k0 = int(dut.prob_k0.value)
        prob_k1 = int(dut.prob_k1.value)
        prob_k2 = int(dut.prob_k2.value)
        prob_k3 = int(dut.prob_k3.value)
        
        # Convert to float
        got = [
            fixed_to_float(prob_k0),
            fixed_to_float(prob_k1),
            fixed_to_float(prob_k2),
            fixed_to_float(prob_k3)
        ]
        
        # Compare with expected
        expected = tc['expected']
        tolerance = 1e-6
        
        for k, (g, e) in enumerate(zip(got, expected)):
            if abs(g - e) > tolerance:
                raise TestFailure(f"{tc['name']} k={k}: expected {e}, got {g}")
            dut._log.info(f"  k={k}: {g} (expected {e}) OK")
    
    dut._log.info("All tests passed!")