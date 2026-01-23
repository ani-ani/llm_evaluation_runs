import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
NUM_PLAYERS = 8
NUM_HOLES = 8
SCORE_WIDTH = 8
RANK_WIDTH = 4
LL_MAX = 255
CLK_PERIOD_NS = 10

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
# EXPECTED RESULT COMPUTATION (reference model)
# ============================================================================
def compute_min_ranks(scores):
    """
    Compute minimum possible rank for each player using brute force.
    scores: 2D list (8x8) of integers.
    Returns: list of 8 min ranks.
    """
    min_ranks = [LL_MAX] * NUM_PLAYERS  # initialize with high value
    
    # Iterate over all possible ℓ from 1 to 255
    for L in range(1, LL_MAX + 1):
        # Compute adjusted totals for all players
        adjusted = [0] * NUM_PLAYERS
        for i in range(NUM_PLAYERS):
            total = 0
            for j in range(NUM_HOLES):
                sc = scores[i][j]
                total += sc if sc <= L else L
            adjusted[i] = total
        
        # Compute ranks for this ℓ
        for i in range(NUM_PLAYERS):
            rank = 0
            for k in range(NUM_PLAYERS):
                if adjusted[k] <= adjusted[i]:
                    rank += 1
            # Update minimum rank
            if rank < min_ranks[i]:
                min_ranks[i] = rank
    
    return min_ranks

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_mini_golf_min_rank(dut):
    """Test the MiniGolfMinRank module."""
    
    dut._log.info("Starting test for MiniGolfMinRank module")
    
    # Start clock
    clock = Clock(dut.clk, CLK_PERIOD_NS, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    
    # Initialize all scores to 0
    for i in range(NUM_PLAYERS):
        for j in range(NUM_HOLES):
            sig_name = f"score_{i}_{j}"
            if has_signal(dut, sig_name):
                getattr(dut, sig_name).value = 0
    
    # Perform reset sequence
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = []
    
    # Test case 1: based on first example, padded
    scores1 = [[0]*NUM_HOLES for _ in range(NUM_PLAYERS)]
    orig1 = [
        [2, 2, 2],
        [4, 2, 1],
        [4, 4, 1]
    ]
    for i in range(3):
        for j in range(3):
            scores1[i][j] = orig1[i][j]
    expected1 = compute_min_ranks(scores1)
    test_cases.append(("Example1", scores1, expected1))
    
    # Test case 2: based on second example, padded
    scores2 = [[0]*NUM_HOLES for _ in range(NUM_PLAYERS)]
    orig2 = [
        [3, 1, 2, 2],
        [4, 3, 2, 2],
        [6, 6, 3, 2],
        [7, 3, 4, 3],
        [3, 4, 2, 4],
        [2, 3, 3, 5]
    ]
    for i in range(6):
        for j in range(4):
            scores2[i][j] = orig2[i][j]
    expected2 = compute_min_ranks(scores2)
    test_cases.append(("Example2", scores2, expected2))
    
    # Test case 3: all zeros
    scores3 = [[0]*NUM_HOLES for _ in range(NUM_PLAYERS)]
    expected3 = compute_min_ranks(scores3)
    test_cases.append(("AllZeros", scores3, expected3))
    
    # Run each test case
    for case_name, scores, expected in test_cases:
        dut._log.info(f"Running test case: {case_name}")
        
        # Write scores to DUT
        for i in range(NUM_PLAYERS):
            for j in range(NUM_HOLES):
                sig_name = f"score_{i}_{j}"
                if has_signal(dut, sig_name):
                    val = clamp_to_width(scores[i][j], SCORE_WIDTH)
                    getattr(dut, sig_name).value = val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        if has_signal(dut, 'done'):
            timeout = 10000
            for _ in range(timeout):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            else:
                raise TestFailure(f"Timeout waiting for done in {case_name}")
        else:
            # Combinational design - wait for propagation
            await Timer(1000, units='ns')
        
        # Read results
        results = []
        for i in range(NUM_PLAYERS):
            sig_name = f"min_rank_{i}"
            if has_signal(dut, sig_name):
                val = getattr(dut, sig_name).value
                if is_value_defined(val):
                    results.append(int(val))
                else:
                    results.append(None)
            else:
                results.append(None)
        
        # Verify
        for i in range(NUM_PLAYERS):
            if results[i] is None:
                raise TestFailure(f"min_rank_{i} undefined in {case_name}")
            if results[i] != expected[i]:
                raise TestFailure(
                    f"Player {i}: expected {expected[i]}, got {results[i]} in {case_name}"
                )
        
        dut._log.info(f"  PASS: {case_name}")
    
    dut._log.info("All tests passed")
