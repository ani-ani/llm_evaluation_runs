import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
MAX_PAIRS = 8
MAX_CANDIDATES = 8
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
# TEST CASE DEFINITIONS
# ============================================================================

# Scaled test cases for hardware implementation
# Format: (n, [(a1,b1), (a2,b2), ...], expected_result, description)
TEST_CASES = [
    (
        3,
        [(17, 18), (15, 24), (12, 15)],
        2,  # Any divisor >1 that works: 2, 3, 6 all valid
        "Basic example from problem"
    ),
    (
        2,
        [(10, 16), (7, 17)],
        -1,
        "No common divisor case"
    ),
    (
        5,
        [(90, 108), (45, 105), (75, 40), (165, 175), (33, 30)],
        3,  # 3 works, 5 also works
        "Third example from problem"
    ),
    (
        1,
        [(10, 9)],
        2,  # Either 2 or 3 works
        "Single pair case"
    ),
    (
        2,
        [(2, 2), (3, 3)],
        -1,
        "No overlap between pairs"
    ),
    (
        3,
        [(5, 15), (125, 3), (3, 3)],
        3,
        "First pair divisible by 5, second by 3"
    ),
    (
        2,
        [(1999999973, 1999999943), (1999999973, 1999999943)],
        1999999943,
        "Large prime numbers"
    ),
    (
        2,
        [(21, 35), (33, 65)],
        3,
        "Small numbers with common factors"
    )
]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_wcd_finder(dut):
    """Main test for WCD finder module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Wait for reset to complete
    await RisingEdge(dut.clk)
    
    passed = 0
    failed = 0
    
    for test_idx, (n, pairs, expected, description) in enumerate(TEST_CASES):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {test_idx + 1}: {description}")
        cocotb.log.info(f"Input: {n} pairs: {pairs}")
        cocotb.log.info(f"Expected: {expected}")
        
        try:
            # Feed first pair to start
            a0, b0 = pairs[0]
            dut.a_in.value = clamp_to_width(a0, DATA_WIDTH)
            dut.b_in.value = clamp_to_width(b0, DATA_WIDTH)
            dut.pair_count.value = n
            
            # Pulse start
            await start_computation(dut)
            
            # Feed remaining pairs sequentially
            for i in range(1, n):
                await RisingEdge(dut.clk)
                a, b = pairs[i]
                dut.a_in.value = clamp_to_width(a, DATA_WIDTH)
                dut.b_in.value = clamp_to_width(b, DATA_WIDTH)
                
                # Wait for internal processing
                await Timer(10, units='ns')
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.wcd_result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.wcd_result.value)
            valid = int(dut.valid.value)
            
            # Check result
            if expected == -1:
                if valid != 0:
                    raise TestFailure(f"Expected no solution (valid=0), got valid={valid}, result={result}")
                cocotb.log.info(f"  PASS: Correctly returned no solution")
            else:
                if valid == 0:
                    raise TestFailure(f"Expected valid solution, but valid=0")
                
                # Check if result works for all pairs
                works = True
                for a, b in pairs:
                    if result <= 1 or (a % result != 0 and b % result != 0):
                        works = False
                        break
                
                if not works:
                    raise TestFailure(f"Result {result} does not divide any element in all pairs")
                
                cocotb.log.info(f"  PASS: Got valid result {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            
        # Reset between tests
        await reset_dut(dut)
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"FINAL RESULTS: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")

# ============================================================================
# BONUS: ADDITIONAL COMPREHENSIVE TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Additional edge case tests."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    edge_cases = [
        (1, [(1000000007, 998244353)], 998244353, "Large primes - second value"),
        (1, [(999999733, 999999733)], 999999733, "Same large prime twice"),
        (2, [(1000000007, 1000000007), (1000000007, 1000000007)], 1000000007, "All same large value"),
        (2, [(11, 11), (22, 22)], 11, "Multiples"),
        (2, [(3, 5), (6, 7)], -1, "No common divisor"),
        (3, [(6, 35), (10, 21), (2, 2)], 2, "Small case with multiple options")
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (n, pairs, expected, description) in enumerate(edge_cases):
        cocotb.log.info(f"\nEdge Test {test_idx + 1}: {description}")
        
        try:
            a0, b0 = pairs[0]
            dut.a_in.value = clamp_to_width(a0, DATA_WIDTH)
            dut.b_in.value = clamp_to_width(b0, DATA_WIDTH)
            dut.pair_count.value = n
            
            await start_computation(dut)
            
            for i in range(1, n):
                await RisingEdge(dut.clk)
                a, b = pairs[i]
                dut.a_in.value = clamp_to_width(a, DATA_WIDTH)
                dut.b_in.value = clamp_to_width(b, DATA_WIDTH)
                await Timer(10, units='ns')
            
            await wait_for_done(dut)
            
            result = int(dut.wcd_result.value)
            valid = int(dut.valid.value)
            
            if expected == -1:
                if valid != 0:
                    raise TestFailure(f"Expected no solution, got result={result}")
            else:
                if valid == 0:
                    raise TestFailure(f"Expected valid solution, got valid=0")
                # Verify result works
                works = True
                for a, b in pairs:
                    if result <= 1 or (a % result != 0 and b % result != 0):
                        works = False
                        break
                if not works:
                    raise TestFailure(f"Result {result} doesn't work for all pairs")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            
        await reset_dut(dut)
        await RisingEdge(dut.clk)
    
    cocotb.log.info(f"\nEdge cases: {passed}/{passed+failed} passed")
    if failed > 0:
        raise TestFailure(f"{failed} edge case(s) failed")