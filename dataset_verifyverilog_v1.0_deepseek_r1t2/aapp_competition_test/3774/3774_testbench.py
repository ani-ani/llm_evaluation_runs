import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
RESULT_WIDTH = 32
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

async def wait_for_combinational(dut, timeout_ns=1000):
    """Wait for combinational logic to settle."""
    elapsed = 0
    check_interval = 10  # ns
    
    while elapsed < timeout_ns:
        await Timer(check_interval, units='ns')
        elapsed += check_interval
        
        # Check if output is valid (not X/Z)
        if is_value_defined(dut.result.value):
            return int(dut.result.value)
    
    raise TestFailure(f"Output not valid after {timeout_ns}ns")

# ============================================================================
# EXPECTED RESULT FUNCTION
# ============================================================================

def compute_expected(n, m):
    """Compute expected result for given n, m."""
    # Ensure n <= m
    if n > m:
        n, m = m, n
    # Case n == 1
    if n == 1:
        r = m % 6
        min_val = r if r < 3 else 6 - r
        return m - min_val
    # Case n == 2
    elif n == 2:
        if m == 2:
            return 0
        elif m == 3:
            return 4
        elif m == 7:
            return 12
        else:
            return 2 * m
    # Case n >= 3
    else:
        prod = n * m
        if (n & 1) and (m & 1):
            prod -= 1
        return prod

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_chessmen(dut):
    """Test the max_chessmen module with various test cases."""
    
    # Define test cases: (n, m, expected)
    test_cases = [
        # n = 1 cases
        (1, 1, 0),
        (1, 2, 0),
        (1, 3, 0),
        (1, 4, 2),
        (1, 5, 4),
        (1, 6, 6),
        (1, 7, 6),
        (1, 8, 6),
        (1, 9, 6),
        (1, 10, 8),
        (1, 12, 12),
        (1, 13, 12),
        (1, 14, 12),
        (1, 15, 12),
        (1, 16, 14),
        (1, 17, 16),
        # n = 2 cases
        (2, 2, 0),
        (2, 3, 4),
        (2, 4, 8),
        (2, 5, 10),
        (2, 6, 12),
        (2, 7, 12),
        (2, 8, 16),
        (2, 9, 18),
        (2, 10, 20),
        (2, 11, 22),
        (2, 12, 24),
        (2, 19, 38),
        (2, 20, 40),
        # n >= 3 cases, both even
        (3, 4, 12),
        (4, 4, 16),
        (4, 5, 20),
        (4, 6, 24),
        (4, 7, 28),
        (4, 8, 32),
        (4, 9, 36),
        # n >= 3 cases, both odd
        (3, 3, 8),
        (3, 5, 14),
        (3, 7, 20),
        (5, 5, 24),
        (5, 7, 34),
        (7, 7, 48),
        (9, 9, 80),
        (11, 11, 120),
        # Mixed parity (one even, one odd) => product
        (3, 6, 18),
        (5, 6, 30),
        (5, 8, 40),
        (7, 8, 56),
        (8, 9, 72),
        # Larger values within 16-bit
        (100, 100, 10000),
        (101, 101, 10200),
        (255, 255, 65024),
        (65535, 65535, 4294836224),
        (65535, 65534, 4294770690),
        (256, 256, 65536),
    ]
    
    dut._log.info(f"Running {len(test_cases)} test cases")
    
    passed = 0
    failed = 0
    
    for i, (n, m, expected) in enumerate(test_cases):
        # Clamp inputs to DATA_WIDTH
        n_val = clamp_to_width(n, DATA_WIDTH)
        m_val = clamp_to_width(m, DATA_WIDTH)
        
        # Set inputs
        if has_signal(dut, 'n'):
            dut.n.value = n_val
        else:
            raise TestFailure(f"Signal 'n' not found")
        
        if has_signal(dut, 'm'):
            dut.m.value = m_val
        else:
            raise TestFailure(f"Signal 'm' not found")
        
        # Wait for combinational logic to settle
        try:
            await wait_for_combinational(dut, timeout_ns=1000)
        except TestFailure as e:
            dut._log.error(f"Test {i+1} ({n}, {m}): {e}")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Test {i+1} ({n}, {m}): result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        # Compare with expected
        if result == expected:
            dut._log.info(f"Test {i+1} ({n}, {m}): PASS (result = {result})")
            passed += 1
        else:
            dut._log.error(f"Test {i+1} ({n}, {m}): FAIL - expected {expected}, got {result}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")