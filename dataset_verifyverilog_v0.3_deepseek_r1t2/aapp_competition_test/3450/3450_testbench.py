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
# CONFIGURATION
# ============================================================================

DATA_WIDTH = 10      # For n input
RESULT_WIDTH = 10    # For result output (0-999)
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(2):
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

async def start_computation(dut, n_value):
    """Set n and pulse start signal."""
    dut.n.value = clamp_to_width(n_value, DATA_WIDTH)
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================

def compute_trailing_three(n):
    """Python reference for the algorithm."""
    if n == 0:
        return 1
    
    product = 1
    count2 = 0
    count5 = 0
    
    for i in range(1, n + 1):
        x = i
        # Count and remove factors of 2
        while x % 2 == 0:
            count2 += 1
            x //= 2
        # Count and remove factors of 5
        while x % 5 == 0:
            count5 += 1
            x //= 5
        product = (product * x) % 10000  # Keep enough precision
    
    # Remove extra factors of 2
    extra_twos = count2 - count5
    product = (product * pow(2, extra_twos, 1000)) % 1000
    
    return product

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_trailing_three(dut):
    """Test the trailing three digits module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, expected_output, description)
    # Scaled down from original problem
    test_cases = [
        (5, 12, "5! = 120 -> 12"),
        (14, 912, "14! = 87178291200 -> 912"),
        (10, 8, "10! = 3628800 -> 8"),
        (15, 368, "15! = 1307674368000 -> 368"),
        (20, 176, "20! = 2432902008176640000 -> 176"),
        (25, 44, "25! has many zeros -> 44"),
        (1, 1, "1! = 1 -> 1"),
        (2, 2, "2! = 2 -> 2"),
        (3, 6, "3! = 6 -> 6"),
        (4, 24, "4! = 24 -> 24"),
    ]
    
    passed = 0
    failed = 0
    
    for n_val, expected, description in test_cases:
        dut._log.info(f"Test: {description}")
        
        try:
            # Start computation
            await start_computation(dut, n_val)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=500)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  PASS: n={n_val}, result={result}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")