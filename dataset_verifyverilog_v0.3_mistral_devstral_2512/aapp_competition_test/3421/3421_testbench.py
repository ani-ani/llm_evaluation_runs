import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 1
ARRAY_SIZE = 16
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
# TEST CASE GENERATION
# ============================================================================

def str_to_int(s):
    """Convert string of '0' and '1' to integer bit vector, LSB = first char."""
    val = 0
    for i, c in enumerate(s):
        if c == '1':
            val |= (1 << i)
    return val

def compute_expected(k, s):
    """Compute expected best subsequence start (1-based) and length."""
    n = len(s)
    best_start = 0
    best_len = 0
    best_ones = 0
    
    for i in range(n):
        count = 0
        for j in range(i, n):
            if s[j] == '1':
                count += 1
            length = j - i + 1
            if length >= k:
                if best_len == 0:
                    best_start = i
                    best_len = length
                    best_ones = count
                elif count * best_len > best_ones * length:
                    best_start = i
                    best_len = length
                    best_ones = count
    
    # Convert to 1-based
    return best_start + 1, best_len

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_density_subsequence(dut):
    """Test the max_density_subsequence module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (k, string, expected_start, expected_length, description)
    test_cases = [
        (1, "01", 2, 1, "Single 1 at end"),
        (4, "0110011", 2, 6, "Provided example"),
        (2, "0001", 4, 1, "Single 1 at end, k=2"),
        (3, "111", 1, 3, "All ones, k=3"),
        (3, "101", 1, 3, "Mixed, k=3"),
        (1, "0000", 1, 1, "All zeros, any length 1"),
        (2, "1010", 1, 2, "Alternating, k=2"),
    ]
    
    passed = 0
    failed = 0
    
    for k, s, exp_start, exp_len, description in test_cases:
        cocotb.log.info(f"Test: {description} (k={k}, str='{s}')")
        
        # Compute expected using Python
        python_start, python_len = compute_expected(k, s)
        if python_start != exp_start or python_len != exp_len:
            cocotb.log.warning(f"  Warning: expected {exp_start} {exp_len}, Python got {python_start} {python_len}")
        
        # Prepare inputs
        L = len(s)
        str_int = str_to_int(s)
        
        # Set inputs
        dut.k.value = k
        dut.L.value = L
        dut.str.value = str_int
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read outputs
        if not (is_value_defined(dut.start_index.value) and is_value_defined(dut.length.value)):
            cocotb.log.error(f"  FAIL: Output undefined")
            failed += 1
            continue
        
        start_out = int(dut.start_index.value)
        len_out = int(dut.length.value)
        
        # Verify
        if start_out == exp_start and len_out == exp_len:
            cocotb.log.info(f"  PASS: start={start_out}, length={len_out}")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: expected {exp_start} {exp_len}, got {start_out} {len_out}")
            failed += 1
        
        # Wait one cycle before next test
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
