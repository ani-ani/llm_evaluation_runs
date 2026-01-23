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
MAX_CYCLES = 100

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

async def start_computation(dut, l_val, r_val):
    """Set inputs and pulse start signal."""
    dut.l.value = clamp_to_width(l_val, DATA_WIDTH)
    dut.r.value = clamp_to_width(r_val, DATA_WIDTH)
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================

def sum_odd(n):
    """Sum of all odd numbers from 1 to n."""
    if n <= 0:
        return 0
    terms = (n + 1) // 2
    sum1 = terms * terms
    return sum1

def sum_in_range(l, r):
    """Sum of odd numbers in range [l, r]."""
    return sum_odd(r) - sum_odd(l - 1)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sum_odd_range(dut):
    """Test sum of odd numbers in range using multiple test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from problem statement
    test_cases = [
        (2, 5, 8, "sum_odd_range(2,5) = 3+5 = 8"),
        (5, 7, 12, "sum_odd_range(5,7) = 5+7 = 12"),
        (7, 13, 40, "sum_odd_range(7,13) = 7+9+11+13 = 40"),
    ]
    
    # Additional edge cases
    additional_cases = [
        (1, 1, 1, "Single odd at start"),
        (1, 2, 1, "Range with one odd"),
        (10, 10, 0, "Single even"),
        (1, 3, 4, "First three numbers: 1+3=4"),
        (100, 200, 7500, "Larger range"),
    ]
    
    all_tests = test_cases + additional_cases
    passed = 0
    failed = 0
    
    for i, (l, r, expected, description) in enumerate(all_tests):
        cocotb.log.info(f"Test {i+1}/{len(all_tests)}: {description}")
        
        try:
            # Calculate expected using reference
            expected_result = sum_in_range(l, r)
            
            # Start computation
            await start_computation(dut, l, r)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            actual = int(dut.result.value)
            
            # Verify
            if actual != expected:
                raise TestFailure(f"Expected {expected}, got {actual}")
            
            cocotb.log.info(f"  PASS: result = {actual}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{len(all_tests)} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
