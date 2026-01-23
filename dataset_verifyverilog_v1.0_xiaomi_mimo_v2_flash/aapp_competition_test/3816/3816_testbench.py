import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def wait_for_done(dut, max_cycles=1000):
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
# EXPECTED RESULT COMPUTATION (Python reference)
# ============================================================================

def compute_expected(a, b, c, l):
    """Compute the number of valid ways (Python reference)."""
    # Total ways: C(l+3, 3)
    total = (l + 3) * (l + 2) * (l + 1) // 6
    
    def count_invalid(delta):
        """Count allocations where one side is >= sum of other two."""
        cnt = 0
        for x in range(l + 1):
            if x >= delta:
                diff = x - delta
                M = min(l - x, diff)
                if M >= 0:
                    cnt += (M + 1) * (M + 2) // 2
        return cnt
    
    invalid_a = count_invalid(a - b - c)
    invalid_b = count_invalid(b - a - c)
    invalid_c = count_invalid(c - a - b)
    
    return total - invalid_a - invalid_b - invalid_c

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_triangle_ways(dut):
    """Main test function for triangle_ways module."""
    
    # Configuration
    CLK_PERIOD_NS = 10
    MAX_CYCLES = 1000
    
    # Detect module type (should be sequential)
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'rst_n') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut, cycles=2)
    else:
        dut._log.error("DUT does not have required sequential signals (clk, rst_n, done)")
        raise TestFailure("DUT must be sequential with clk, rst_n, done")
    
    # Test cases: (a, b, c, l, expected)
    test_cases = [
        (1, 1, 1, 2, 4),          # Sample 1
        (1, 2, 3, 1, 2),          # Sample 2
        (10, 2, 1, 7, 0),         # Sample 3
        (1, 2, 1, 5, 20),         # Additional
        (10, 15, 17, 10, 281),    # Additional
        (5, 5, 5, 10, 176),       # Additional
        (5, 7, 30, 100, 71696),   # Additional (scaled down l=100? but l<=31, so we reduce l)
        (5, 5, 5, 31, 5291),      # Additional (l=31 max)
        (4, 2, 5, 28, 1893),      # Additional
        (2, 7, 8, 4, 25),         # Additional
    ]
    
    # Adjust large l values to fit within 0-31 (since inputs are 5-bit)
    # For test cases with l > 31, we scale down l and recompute expected
    scaled_test_cases = []
    for a, b, c, l, exp in test_cases:
        if l > 31:
            l_scaled = min(l, 31)  # Scale down to 31
            exp_scaled = compute_expected(a, b, c, l_scaled)
            scaled_test_cases.append((a, b, c, l_scaled, exp_scaled))
        else:
            scaled_test_cases.append((a, b, c, l, exp))
    
    passed = 0
    failed = 0
    
    for i, (a_val, b_val, c_val, l_val, expected) in enumerate(scaled_test_cases):
        dut._log.info(f"Test {i+1}: a={a_val}, b={b_val}, c={c_val}, l={l_val} (expected={expected})")
        
        # Set inputs
        dut.a.value = a_val
        dut.b.value = b_val
        dut.c.value = c_val
        dut.l.value = l_val
        
        # Wait for next clock edge
        await RisingEdge(dut.clk)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=MAX_CYCLES)
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error("  FAIL: result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        # Compare
        if result != expected:
            dut._log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
        
        # Wait for next clock before next test
        await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
