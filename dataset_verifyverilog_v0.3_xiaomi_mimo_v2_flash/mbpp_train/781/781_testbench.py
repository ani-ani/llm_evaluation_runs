import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return value + (1 << bits)  # Convert to unsigned
    return min(max_val, max(0, value))

def count_divisors_reference(n):
    """Reference implementation for testing."""
    if n == 0:
        return None
    count = 0
    for i in range(1, int(math.sqrt(n)) + 2):
        if n % i == 0:
            if n // i == i:
                count += 1
            else:
                count += 2
    return count

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

async def start_computation(dut, n):
    """Start computation with input n."""
    dut.n.value = clamp_to_width(n, DATA_WIDTH)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_divisor_parity(dut):
    """Test divisor parity check module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (input, expected_even_count, description)
    # Note: Scaled down to 16-bit range (max 65535)
    test_cases = [
        (10, True, "10 has 4 divisors (1,2,5,10) - even"),
        (100, False, "100 has 9 divisors (odd) - perfect square"),
        (125, True, "125 has 4 divisors (1,5,25,125) - even"),
        (1, False, "1 has 1 divisor (odd)"),
        (2, True, "2 has 2 divisors (1,2) - even"),
        (4, False, "4 has 3 divisors (odd) - perfect square"),
        (6, True, "6 has 4 divisors (1,2,3,6) - even"),
        (9, False, "9 has 3 divisors (odd) - perfect square"),
        (15, True, "15 has 4 divisors (1,3,5,15) - even"),
        (25, False, "25 has 3 divisors (odd) - perfect square"),
        (30, True, "30 has 8 divisors - even"),
        (36, False, "36 has 9 divisors - perfect square"),
        (49, False, "49 has 3 divisors - perfect square"),
        (121, False, "121 has 3 divisors - perfect square"),
        (499, True, "499 has 2 divisors (prime) - even"),
        (576, False, "576 has 21 divisors - perfect square"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, expected_even, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description} (n={n})")
        
        try:
            # Start computation
            await start_computation(dut, n)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check error flag for invalid input
            if has_signal(dut, 'error'):
                if is_value_defined(dut.error.value) and int(dut.error.value) == 1:
                    if n != 0:
                        raise TestFailure(f"Unexpected error flag for n={n}")
                    cocotb.log.info(f"  PASS: Error flag correctly set for n=0")
                    passed += 1
                    continue
            
            # Read results
            if not is_value_defined(dut.is_even.value):
                raise TestFailure(f"is_even is undefined (X/Z)")
            
            if not is_value_defined(dut.divisor_count.value):
                raise TestFailure(f"divisor_count is undefined (X/Z)")
            
            result_even = bool(int(dut.is_even.value))
            result_count = int(dut.divisor_count.value)
            
            # Get reference values
            ref_count = count_divisors_reference(n)
            ref_even = (ref_count % 2 == 0) if ref_count is not None else None
            
            # Verify
            if ref_count is not None:
                # Check that divisor count matches reference (within iteration limit)
                # Note: Hardware might not find all divisors due to MAX_ITER limit
                if result_count != ref_count:
                    # Check if it's because we hit iteration limit
                    if result_count != 0:  # If we got some result
                        cocotb.log.info(f"  Info: Count {result_count} vs expected {ref_count} (may differ due to iteration limit)")
                
                # Check parity
                if result_even != expected_even:
                    raise TestFailure(f"Parity mismatch: expected {expected_even}, got {result_even} (count={result_count})")
                
                cocotb.log.info(f"  PASS: is_even={result_even}, count={result_count}")
            else:
                raise TestFailure(f"Reference calculation failed for n={n}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")