import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 16
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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_count_ones(dut):
    """Test the count_ones module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, l, r, expected_output, description)
    # n up to 255, l and r up to 255, r-l <= 255
    test_cases = [
        (7, 2, 5, 4, "Example 1"),
        (10, 3, 10, 5, "Example 2"),
        (0, 1, 1, 0, "n=0"),
        (1, 1, 1, 1, "n=1"),
        (5, 1, 7, 5, "n=5 sequence [1,0,1,1,1,0,1]"),
        (2, 2, 2, 0, "n=2 sequence [1,0,1], position2=0"),
        (255, 1, 255, 255, "n=255 all ones"),
        (128, 1, 255, 128, "n=128 (10000000) pattern"),
        (170, 1, 255, 128, "n=170 (10101010) pattern"),
        (15, 10, 20, 8, "n=15 sequence length 15, range 10-20"),
    ]
    
    passed = 0
    failed = 0
    
    for n, l, r, expected, description in test_cases:
        cocotb.log.info(f"Test: {description} (n={n}, l={l}, r={r})")
        
        # Write inputs
        dut.n.value = n
        dut.l.value = l
        dut.r.value = r
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=1000)
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.count.value):
            cocotb.log.error("  FAIL: count is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.count.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
        
        # Wait for done to deassert? Not necessary if we pulse start each time.
        # But ensure we are back in IDLE before next test
        await RisingEdge(dut.clk)
        if int(dut.done.value) == 1:
            # Wait until done goes low (or just proceed, since start will be low)
            pass
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")