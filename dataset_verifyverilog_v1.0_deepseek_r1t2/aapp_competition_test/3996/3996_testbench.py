import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MOD = 1000000007
INV2 = 500000004
INV3 = 333333336
CLK_PERIOD_NS = 10

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if cocotb value is defined (not X or Z)."""
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
# SEQUENTIAL HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset sequence for active-low reset."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# EXPECTED VALUE CALCULATION
# ============================================================================

def compute_expected(n):
    """Compute expected p/q for given n."""
    if n == 0:
        return 1, 1
    result = pow(2, n, MOD)
    q = (result * INV2) % MOD
    flag = 1 if (n % 2 == 0) else MOD - 1
    p = ((q + flag) * INV3) % MOD
    return p, q

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_barney_probability(dut):
    """Test barney_probability module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, description)
    test_cases = [
        (1, "n=1, odd"),
        (2, "n=2, even"),
        (3, "n=3, odd"),
        (4, "n=4, even"),
        (5, "n=5, odd"),
        (6, "n=6, even"),
        (7, "n=7, odd"),
        (8, "n=8, even"),
        (9, "n=9, odd"),
        (10, "n=10, even"),
        (15, "n=15, odd"),
        (16, "n=16, even"),
        (32, "n=32, even"),
        (64, "n=64, even"),
        (127, "n=127, odd"),
        (128, "n=128, even"),
        (255, "n=255, odd"),
    ]
    
    passed = 0
    failed = 0
    
    for n, description in test_cases:
        cocotb.log.info(f"Testing: {description}")
        
        try:
            # Set inputs
            dut.n_in.value = clamp_to_width(n, 8)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=100)
            
            # Read results
            if not (is_value_defined(dut.p_out.value) and is_value_defined(dut.q_out.value)):
                raise TestFailure("Output signals undefined (X/Z)")
            
            p_actual = int(dut.p_out.value)
            q_actual = int(dut.q_out.value)
            
            # Compute expected
            p_expected, q_expected = compute_expected(n)
            
            # Verify
            if p_actual != p_expected or q_actual != q_expected:
                raise TestFailure(
                    f"Mismatch: expected {p_expected}/{q_expected}, "
                    f"got {p_actual}/{q_actual}"
                )
            
            cocotb.log.info(f"  PASS: {p_actual}/{q_actual}")
            passed += 1
            
            # Wait one cycle before next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")