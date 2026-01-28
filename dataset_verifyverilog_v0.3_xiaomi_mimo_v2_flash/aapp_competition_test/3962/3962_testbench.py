import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 8                 # Maximum number of guests
DATA_WIDTH = 32       # Bits for each l_i and r_i
RESULT_WIDTH = 64     # Bits for result
CLK_PERIOD_NS = 10
MAX_CYCLES = 200       # For wait_for_done

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
# ARRAY PACKING HELPER
# ============================================================================

def pack_array(values, element_bits=DATA_WIDTH):
    """Pack list of values into single integer, LSB first."""
    result = 0
    for i, val in enumerate(values):
        result |= (val & ((1 << element_bits) - 1)) << (i * element_bits)
    return result

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
# EXPECTED RESULT COMPUTATION
# ============================================================================

def compute_expected(n, pairs):
    """Compute minimal chairs using Python algorithm."""
    l = [p[0] for p in pairs]
    r = [p[1] for p in pairs]
    l.sort()
    r.sort()
    total = n + sum(max(l[i], r[i]) for i in range(n))
    return total

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_circles_of_chairs(dut):
    """Main test function for CirclesOfChairs module."""

    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)

    # Define test cases: (n, list of (l,r), description)
    test_cases = [
        (3, [(1,1), (1,1), (1,1)], "Three guests with l=r=1"),
        (4, [(1,2), (2,1), (3,5), (5,3)], "Four guests from example"),
        (1, [(5,6)], "Single guest"),
        (2, [(1000,0), (0,1000)], "Two guests, large asymmetry"),
        (5, [(100,0), (1234,0), (1032134,0), (1,0), (2,0)], "Five guests, varied l, zero r"),
        (8, [(0,0), (1,1), (2,2), (3,3), (4,4), (5,5), (6,6), (7,7)], "Eight guests, equal pairs"),
        (1, [(0,0)], "Single guest with zeros"),
        (6, [(100,200), (300,400), (500,600), (700,800), (900,1000), (1100,1200)], "Six guests, increasing"),
    ]

    passed = 0
    failed = 0

    for tn, (n, pairs, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {tn+1}: {desc}")
        cocotb.log.info(f"  n = {n}, pairs = {pairs}")

        # Prepare arrays with sentinel values for unused entries
        sentinel = (1 << DATA_WIDTH) - 1  # Max value for unused
        l_vals = [p[0] for p in pairs] + [sentinel] * (N - n)
        r_vals = [p[1] for p in pairs] + [sentinel] * (N - n)

        # Pack and assign
        dut.l_arr_packed.value = pack_array(l_vals)
        dut.r_arr_packed.value = pack_array(r_vals)
        dut.n.value = n

        # Start computation
        await start_computation(dut)

        # Wait for done
        await wait_for_done(dut)

        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"  FAIL: result is undefined (X/Z)")
            failed += 1
            continue

        result = int(dut.result.value)
        expected = compute_expected(n, pairs)

        if result != expected:
            cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1

        # Short wait before next test
        await Timer(100, units='ns')

    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")

    if failed > 0:
        raise TestFailure(f"{failed} tests failed")