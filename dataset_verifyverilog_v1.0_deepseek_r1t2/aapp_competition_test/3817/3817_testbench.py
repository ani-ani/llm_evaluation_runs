import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4      # n and m are 4-bit
ARRAY_SIZE = 8      # Max n
RESULT_WIDTH = 32   # Result width
CLK_PERIOD_NS = 10
MAX_CYCLES = 200     # Plenty for 8 iterations + overhead
MOD = 1000000009

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

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# TEST CASES (scaled to n,m ≤ 8)
# ============================================================================
# Compute expected using Python
def expected_value(n, m):
    pow2m = 1 << m
    res = 1
    for i in range(1, n+1):
        factor = (pow2m - i) % MOD
        res = (res * factor) % MOD
    return res

# Generate test cases for n,m ≤ 8
test_cases = []
for n in range(1, 9):
    for m in range(1, 9):
        # Only include if 2^m - n >= 0 or we want to test zero factor
        # All combos are interesting
        exp = expected_value(n, m)
        test_cases.append((n, m, exp))

# Also add a few edge cases manually
test_cases.extend([
    (1, 1, expected_value(1, 1)),
    (2, 1, expected_value(2, 1)),
    (8, 4, expected_value(8, 4)),
])

# Remove duplicates
seen = set()
unique_cases = []
for case in test_cases:
    key = (case[0], case[1])
    if key not in seen:
        seen.add(key)
        unique_cases.append(case)
test_cases = unique_cases

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_wool_sequence_counter(dut):
    """Test the wool_sequence_counter module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, (n, m, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: n={n}, m={m}, expected={expected}")
        
        try:
            # Set inputs
            dut.n.value = clamp_to_width(n, DATA_WIDTH)
            dut.m.value = clamp_to_width(m, DATA_WIDTH)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
        # Reset before next test
        await reset_dut(dut)
    
    # Summary
    dut._log.info("="*50)
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
