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
MAX_CYCLES = 100

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# VERIFICATION HELPERS
# ============================================================================

def compute_polite_number(n):
    """Compute nth polite number: n + floor(log2(n)) + 1"""
    if n <= 0:
        return 0
    log2_n = 0
    temp = n
    while temp > 1:
        temp >>= 1
        log2_n += 1
    return n + log2_n + 1

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'n'):
        dut.n.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut, n_value):
    """Pulse start signal and set input n."""
    dut.n.value = clamp_to_width(n_value, DATA_WIDTH)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal to be asserted."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_polite_number(dut):
    """Test polite number calculation."""
    
    # Detect required signals
    required_signals = ['clk', 'rst_n', 'start', 'n', 'result', 'done']
    missing = []
    for sig in required_signals:
        if not has_signal(dut, sig):
            missing.append(sig)
    
    if missing:
        raise TestFailure(f"Missing required signals: {', '.join(missing)}")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=3)
    
    # Test cases
    test_cases = [
        (7, 11, "n=7, expected=11"),
        (4, 7, "n=4, expected=7"),
        (9, 13, "n=9, expected=13"),
        (1, 3, "n=1, expected=3"),
        (2, 4, "n=2, expected=4"),
        (3, 6, "n=3, expected=6"),
        (8, 12, "n=8, expected=12"),
        (15, 19, "n=15, expected=19"),
        (16, 21, "n=16, expected=21"),
        (31, 36, "n=31, expected=36"),
        (32, 38, "n=32, expected=38"),
        (127, 135, "n=127, expected=135"),
        (128, 136, "n=128, expected=136"),
        (255, 264, "n=255, expected=264"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_n, expected, description) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}/{len(test_cases)}: {description}")
        
        try:
            # Start computation
            await start_computation(dut, input_n)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=20)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  PASS: result={result}")
            passed += 1
            
            # Wait one cycle between tests
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*60}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")