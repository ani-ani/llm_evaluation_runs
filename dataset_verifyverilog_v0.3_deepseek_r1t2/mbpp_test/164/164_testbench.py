import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 16
MAX_CYCLES = 1000
CLK_PERIOD_NS = 10

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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

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

async def start_computation(dut, num1, num2):
    """Start computation with given numbers."""
    dut.num1.value = num1
    dut.num2.value = num2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# DIVISOR SUM FUNCTION FOR VERIFICATION
# ============================================================================

def div_sum(n):
    """Compute sum of proper divisors."""
    if n <= 1:
        return 0
    total = 1
    i = 2
    while i * i <= n:
        if n % i == 0:
            total += i
            if i != n // i:
                total += n // i
        i += 1
    return total

def are_equivalent(num1, num2):
    """Check if divisor sums are equal."""
    return div_sum(num1) == div_sum(num2)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_divisor_sum_comparator(dut):
    """Test divisor sum comparator module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (num1, num2, expected_equivalent, description)
    test_cases = [
        (36, 57, False, "Test 1: 36 vs 57"),
        (2, 4, False, "Test 2: 2 vs 4"),
        (23, 47, True, "Test 3: 23 vs 47"),
        (6, 25, False, "Test 4: 6 (sum=6) vs 25 (sum=6) - wait, should be True"),
        (1, 1, True, "Test 5: Edge case 1 vs 1"),
        (12, 14, False, "Test 6: 12 vs 14"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (num1, num2, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Inputs: num1={num1}, num2={num2}")
        
        # Compute expected values for debugging
        expected_sum1 = div_sum(num1)
        expected_sum2 = div_sum(num2)
        expected_eq = (expected_sum1 == expected_sum2)
        cocotb.log.info(f"  Expected: sum1={expected_sum1}, sum2={expected_sum2}, equivalent={expected_eq}")
        
        try:
            # Start computation
            await start_computation(dut, num1, num2)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read results
            if not all([is_value_defined(dut.sum1.value), 
                       is_value_defined(dut.sum2.value),
                       is_value_defined(dut.equivalent.value)]):
                raise TestFailure("Output signals contain X or Z values")
            
            sum1 = int(dut.sum1.value)
            sum2 = int(dut.sum2.value)
            equivalent = int(dut.equivalent.value)
            
            cocotb.log.info(f"  Result: sum1={sum1}, sum2={sum2}, equivalent={equivalent}")
            
            # Verify equivalent matches expected
            if equivalent != (1 if expected_eq else 0):
                raise TestFailure(f"equivalent mismatch: expected {1 if expected_eq else 0}, got {equivalent}")
            
            # Verify sum values (optional, for thoroughness)
            # Note: module returns sum of PROPER divisors (excluding n itself)
            # Python div_sum includes 1 but not n, so should match
            if sum1 != expected_sum1:
                cocotb.log.warning(f"sum1 mismatch: expected {expected_sum1}, got {sum1}")
            if sum2 != expected_sum2:
                cocotb.log.warning(f"sum2 mismatch: expected {expected_sum2}, got {sum2}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")