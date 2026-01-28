import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
MAX_OTHERS = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_other_scores(dut, scores):
    """Write other scores to individual ports."""
    for i in range(min(len(scores), MAX_OTHERS)):
        if has_signal(dut, f'other_scores_{i}'):
            getattr(dut, f'other_scores_{i}').value = clamp_to_width(scores[i], DATA_WIDTH)
        else:
            raise TestFailure(f"Cannot find port: other_scores_{i}")
    # Zero out remaining
    for i in range(len(scores), MAX_OTHERS):
        if has_signal(dut, f'other_scores_{i}'):
            getattr(dut, f'other_scores_{i}').value = 0

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_betting_guarantee(dut):
    """Test betting guarantee computation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (julia_score, other_scores, expected_guarantee, description)
    test_cases = [
        # Sample Input 1
        (3, [3, 2], 1, "Julia=3, others=[3,2] -> guarantee=1"),
        # Sample Input 2
        (8, [4, 3, 5, 2], 6, "Julia=8, others=[4,3,5,2] -> guarantee=6"),
        # Edge case: Julia far ahead
        (10, [5, 4, 3], 7, "Julia=10, others=[5,4,3] -> guarantee=7"),
        # Edge case: Julia tied with all
        (5, [5, 5, 5], 2, "Julia=5, others=[5,5,5] -> guarantee=2"),
        # Edge case: Only one other
        (7, [5], 2, "Julia=7, others=[5] -> guarantee=2"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (julia, others, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs
            dut.julia_score.value = clamp_to_width(julia, DATA_WIDTH)
            await write_other_scores(dut, others)
            dut.valid_count.value = len(others)
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.guarantee_matches.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.guarantee_matches.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
