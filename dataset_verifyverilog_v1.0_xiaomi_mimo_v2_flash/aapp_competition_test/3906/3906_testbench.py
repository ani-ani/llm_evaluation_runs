import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 100
MOD = 1000000007

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
# EXPECTED VALUE COMPUTATION
# ============================================================================

def compute_expected(n, m):
    """Compute expected result using Python (scaled down, works for n,m <= 16)."""
    # Compute Fibonacci numbers F(0)=1, F(1)=2
    max_idx = max(n-1, m-1)
    fib = [0] * (max_idx + 2)  # Ensure at least two elements
    fib[0] = 1
    if max_idx >= 1:
        fib[1] = 2
    for i in range(2, max_idx + 1):
        fib[i] = (fib[i-1] + fib[i-2]) % MOD
    
    fn = fib[n-1] if n >= 1 else 1  # n-1=0 -> F(0)=1
    fm = fib[m-1] if m >= 1 else 1  # m-1=0 -> F(0)=1
    
    result = (2 * ((fn + fm - 1) % MOD)) % MOD
    return result

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_random_pictures(dut):
    """Test random_pictures module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, m, description)
    # Only include values <= 16 for scaled implementation
    test_cases = [
        (1, 1, "1x1 grid"),
        (1, 2, "1x2 grid"),
        (2, 1, "2x1 grid"),
        (2, 2, "2x2 grid"),
        (2, 3, "2x3 grid"),
        (3, 2, "3x2 grid"),
        (3, 3, "3x3 grid"),
        (1, 5, "1x5 grid"),
        (5, 1, "5x1 grid"),
        (4, 4, "4x4 grid"),
        (8, 8, "8x8 grid"),
        (16, 16, "16x16 grid"),
        (1, 16, "1x16 grid"),
        (16, 1, "16x1 grid"),
        (2, 15, "2x15 grid"),
        (15, 2, "15x2 grid"),
    ]
    
    passed = 0
    failed = 0
    
    for n, m, description in test_cases:
        cocotb.log.info(f"Test: {description} (n={n}, m={m})")
        
        try:
            # Set inputs
            dut.n.value = n
            dut.m.value = m
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            expected = compute_expected(n, m)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait one cycle between tests
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
