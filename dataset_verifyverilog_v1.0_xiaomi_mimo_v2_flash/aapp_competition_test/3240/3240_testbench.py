import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION – match HDL design
# ============================================================================
MAX_V = 10          # maximum voters (including yourself)
MAX_K = 8           # maximum positions
CLK_PERIOD_NS = 10
MAX_CYCLES = 100000  # enough for ~70k cycles

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
# TESTBENCH HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active‑low)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal, handling X/Z."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# REFERENCE IMPLEMENTATION (Python)
# ============================================================================

def compute_optimal(k, v, probs, ballots):
    """
    probs and ballots are lists of length v-1, with probs in [0,1].
    Returns optimal b_v.
    Uses subset enumeration with integer scaling by 256.
    """
    M = 1 << k
    num_other = v - 1
    # Scale probabilities to integers 0..256
    probs_int = [int(round(p * 256)) for p in probs]
    # Probabilities for not voting: 256 - p_int
    not_probs = [256 - p for p in probs_int]
    
    # Distribution array: size M, each entry is 128-bit integer (Python int)
    dist = [0] * M
    
    # Iterate over all subsets
    for subset in range(1 << num_other):
        total_b = 0
        prob_total = 1  # start with 1 (scaled by 256 per voter later)
        for i in range(num_other):
            if (subset >> i) & 1:
                total_b += ballots[i]
                prob_total *= probs_int[i]
            else:
                prob_total *= not_probs[i]
        # Note: prob_total is product of 8‑bit numbers, can be up to 256^9 (≈ 2^72).
        idx = total_b % M
        dist[idx] += prob_total
    
    # Now evaluate each candidate b_v
    best_b = 0
    best_expected = -1
    for b_v in range(M):
        expected = 0
        for r in range(M):
            total = (r + b_v) % M
            pop = bin(total).count('1')
            expected += dist[r] * pop
        if expected > best_expected:
            best_expected = expected
            best_b = b_v
    return best_b

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_binary_town(dut):
    """Test the binary_town_election module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases – adapted to scaled integer probabilities
    # Format: (k, v, list of (p, b) for other voters)
    test_cases = [
        # Sample 1: k=2, v=2, one voter: p=0.5, b=1
        (2, 2, [(0.5, 1)]),
        # Sample 2: k=4, v=3, two voters: (1,11), (0.4,1)
        (4, 3, [(1.0, 11), (0.4, 1)]),
        # Sample 3: k=8, v=10, nine voters (scaled down to 9 because our module supports max 9 others)
        (8, 10, [
            (0.2774, 31),
            (0.1377, 156),
            (0.2958, 162),
            (0.8703, 149),
            (0.5157, 16),
            (0.8503, 145),
            (0.5338, 44),
            (0.6871, 9),
            (0.5280, 161),
        ]),
    ]
    
    for case_idx, (k, v, voter_info) in enumerate(test_cases):
        dut._log.info(f"\nTest case {case_idx+1}: k={k}, v={v}")
        
        # Extract probabilities and ballots
        probs = [p for p, b in voter_info]
        ballots = [b for p, b in voter_info]
        num_other = v - 1
        
        # Compute reference answer using Python
        ref_best = compute_optimal(k, v, probs, ballots)
        dut._log.info(f"Reference answer: {ref_best}")
        
        # Write inputs to DUT
        dut.k.value = k
        dut.v.value = v
        
        # Clear all p and b ports (set to 0 for unused)
        for i in range(9):
            getattr(dut, f'p{i}').value = 0
            getattr(dut, f'b{i}').value = 0
        
        # Fill used voters
        for i in range(num_other):
            p_int = int(round(probs[i] * 256))
            b_val = ballots[i]
            getattr(dut, f'p{i}').value = clamp_to_width(p_int, 8)
            getattr(dut, f'b{i}').value = clamp_to_width(b_val, 8)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut, max_cycles=200000)  # allow plenty of time
        
        # Read result
        if not is_value_defined(dut.best_b.value):
            raise TestFailure(f"best_b is undefined (X/Z)")
        
        dut_best = int(dut.best_b.value)
        dut._log.info(f"DUT answer: {dut_best}")
        
        # Verify
        if dut_best != ref_best:
            raise TestFailure(f"Mismatch: expected {ref_best}, got {dut_best}")
        
        dut._log.info("PASS")
    
    dut._log.info("\n" + "="*50)
    dut._log.info("All tests passed!")
