import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_CONTESTS = 10          # Max n (including last contest)
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS (as required by template)
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
# SEQUENTIAL MODULE HELPERS
# ============================================================================
async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.scores_valid.value = 0
    dut.end_of_contestants.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def send_score(dut, score, is_your_score=False):
    """Send one score to the DUT."""
    dut.scores_valid.value = 1
    dut.scores_in.value = clamp_to_width(score, DATA_WIDTH)
    dut.is_your_score.value = 1 if is_your_score else 0
    await RisingEdge(dut.clk)
    dut.scores_valid.value = 0
    # Small delay to allow internal capture (if needed)
    await Timer(1, units='ns')

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_worst_rank(dut):
    """Test the WorstRank module with provided examples."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, m, your_scores, other_scores_list, expected_rank)
    # Note: n = number of contests (including last), so n-1 scores per contestant
    test_cases = [
        (4, 2, [50,50,75], [[25,25,25]], 2),   # Sample 1
        (5, 2, [50,50,50,50], [[25,25,25,25]], 1),   # Sample 2
        (2, 4, [90], [[1], [3], [2]], 3),      # Additional test
    ]
    
    passed = 0
    failed = 0
    
    for case_idx, (n, m, your_scores, other_scores_list, expected_rank) in enumerate(test_cases):
        cocotb.log.info(f"Test case {case_idx+1}: n={n}, m={m}")
        
        try:
            # Set n_minus_one
            dut.n_minus_one.value = n - 1
            
            # Pulse start
            await start_computation(dut)
            
            # Send your scores
            for score in your_scores:
                await send_score(dut, score, is_your_score=True)
            
            # Send other contestants' scores
            for i, other_scores in enumerate(other_scores_list):
                for score in other_scores:
                    await send_score(dut, score, is_your_score=False)
                # After each contestant, we don't set end_of_contestants yet
                # Only after the last contestant's last score
                if i == len(other_scores_list) - 1:
                    # Set end_of_contestants on the clock edge after the last score
                    # We already sent the last score above; now we need to signal end
                    # We'll set end_of_contestants for one cycle
                    dut.end_of_contestants.value = 1
                    await RisingEdge(dut.clk)
                    dut.end_of_contestants.value = 0
            
            # If there are no other contestants (m=1), we still need to signal end after your scores
            if len(other_scores_list) == 0:
                dut.end_of_contestants.value = 1
                await RisingEdge(dut.clk)
                dut.end_of_contestants.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.worst_rank.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.worst_rank.value)
            
            if result != expected_rank:
                raise TestFailure(f"Expected {expected_rank}, got {result}")
            
            cocotb.log.info(f"  PASS: worst_rank = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset for next test case
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
