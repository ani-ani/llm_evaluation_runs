import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 10      # For weight
TASTINESS_WIDTH = 16
RESULT_WIDTH = 64
FRAC_BITS = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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

# Fixed-point conversion helpers
def float_to_fixed(f, frac_bits=FRAC_BITS):
    """Convert float to fixed-point integer."""
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=FRAC_BITS):
    """Convert fixed-point integer to float."""
    return fixed / (1 << frac_bits)

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
# TEST CASES
# ============================================================================

# We adapt the problem to our module:
# - At most 1 discrete dish, at most 2 continuous dishes.
# - Weight w scaled to <= 1000 (we'll use 15 in tests).
# - We'll compute expected results in Python.

def compute_expected(discrete, continuous1, continuous2, target_weight):
    """Compute expected maximum tastiness in Python."""
    max_total = -10**18
    found = False
    
    # Discrete dish parameters
    if discrete:
        d_valid, d_weight, d_t, d_dt = discrete
    else:
        d_valid = False
    
    # Continuous dishes
    c1_valid = False
    c1_t = c1_dt = 0
    if continuous1:
        c1_valid, c1_t, c1_dt = continuous1
    c2_valid = False
    c2_t = c2_dt = 0
    if continuous2:
        c2_valid, c2_t, c2_dt = continuous2
    
    # Iterate over possible discrete counts
    max_N = 0
    if d_valid and d_weight > 0:
        max_N = target_weight // d_weight
    
    for N in range(max_N + 1):
        remaining = target_weight - N * d_weight if d_valid else target_weight
        if remaining < 0:
            continue
        
        # Discrete tastiness
        if d_valid:
            disc_tastiness = N * d_t - d_dt * N * (N - 1) // 2
        else:
            disc_tastiness = 0
        
        # Continuous tastiness for remaining weight
        cont_tastiness = 0
        if remaining == 0:
            cont_tastiness = 0
        else:
            if not c1_valid and not c2_valid:
                if remaining > 0:
                    continue  # impossible, skip
            elif c1_valid and not c2_valid:
                cont_tastiness = c1_t * remaining - (c1_dt * remaining * remaining) / 2
            elif not c1_valid and c2_valid:
                cont_tastiness = c2_t * remaining - (c2_dt * remaining * remaining) / 2
            else:
                # Two continuous dishes: solve optimal allocation
                t1, dt1 = c1_t, c1_dt
                t2, dt2 = c2_t, c2_dt
                
                # Case 1: both dt zero
                if dt1 == 0 and dt2 == 0:
                    cont_tastiness = max(t1, t2) * remaining
                # Case 2: one dt zero
                elif dt1 == 0:
                    if t1 >= t2:
                        cont_tastiness = t1 * remaining
                    else:
                        X2_bound = (t2 - t1) / dt2
                        if remaining <= X2_bound:
                            cont_tastiness = t2 * remaining - 0.5 * dt2 * remaining * remaining
                        else:
                            X2 = X2_bound
                            X1 = remaining - X2
                            cont_tastiness = t1 * X1 + (t2 * X2 - 0.5 * dt2 * X2 * X2)
                elif dt2 == 0:
                    if t2 >= t1:
                        cont_tastiness = t2 * remaining
                    else:
                        X1_bound = (t1 - t2) / dt1
                        if remaining <= X1_bound:
                            cont_tastiness = t1 * remaining - 0.5 * dt1 * remaining * remaining
                        else:
                            X1 = X1_bound
                            X2 = remaining - X1
                            cont_tastiness = t2 * X2 + (t1 * X1 - 0.5 * dt1 * X1 * X1)
                else:
                    # Both dt > 0
                    # Compute λ
                    sum_t_over_dt = t1 / dt1 + t2 / dt2
                    sum_inv_dt = 1 / dt1 + 1 / dt2
                    lam = (sum_t_over_dt - remaining) / sum_inv_dt
                    if lam <= min(t1, t2):
                        x1 = (t1 - lam) / dt1
                        x2 = (t2 - lam) / dt2
                        cont_tastiness = 0.5 * ((t1*t1 - lam*lam) / dt1 + (t2*t2 - lam*lam) / dt2)
                    else:
                        # One dish gets zero, solve with remaining dish
                        if lam > t1 and lam > t2:
                            # Should not happen, but fallback
                            cont_tastiness = 0
                        elif lam > t1:
                            # Dish 1 gets zero, allocate to dish 2
                            cont_tastiness = t2 * remaining - 0.5 * dt2 * remaining * remaining
                        else:  # lam > t2
                            cont_tastiness = t1 * remaining - 0.5 * dt1 * remaining * remaining
        
        total = disc_tastiness + cont_tastiness
        if total > max_total:
            max_total = total
            found = True
    
    if not found:
        return None
    return max_total

# Test case definitions
# Format: (discrete, continuous1, continuous2, target_weight, expected)
# discrete: (weight, t, dt) if present else None
# continuous: (t, dt) if present else None
test_cases = [
    # Example 1: 2 dishes, discrete (4,10,1), continuous (6,1), w=15 -> 40.5
    ((4, 10, 1), (6, 1), None, 15, 40.5),
    # Example 2: 3 dishes, discrete (4,10,1), continuous (6,1) and (9,3), w=15 -> 49.0
    ((4, 10, 1), (6, 1), (9, 3), 15, 49.0),
    # Example 3 from input: 2 19
    # D 4 5 1, D 6 3 2 -> two discrete dishes, but we only handle one discrete.
    # We'll skip this as our module only supports one discrete.
    # We'll add a simple test for one discrete, one continuous
    ((4, 5, 1), (3, 0), None, 10, 50.0),  # custom
]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_buffet_optimizer(dut):
    """Test the buffet optimizer module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, (disc, cont1, cont2, target_weight, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: target_weight={target_weight}")
        
        # Set up inputs
        if disc is not None:
            dut.discrete_valid.value = 1
            dut.discrete_weight.value = clamp_to_width(disc[0], DATA_WIDTH)
            dut.discrete_t.value = clamp_to_width(disc[1], TASTINESS_WIDTH)
            dut.discrete_dt.value = clamp_to_width(disc[2], TASTINESS_WIDTH)
        else:
            dut.discrete_valid.value = 0
            dut.discrete_weight.value = 0
            dut.discrete_t.value = 0
            dut.discrete_dt.value = 0
        
        if cont1 is not None:
            dut.cont1_valid.value = 1
            dut.cont1_t.value = clamp_to_width(cont1[0], TASTINESS_WIDTH)
            dut.cont1_dt.value = clamp_to_width(cont1[1], TASTINESS_WIDTH)
        else:
            dut.cont1_valid.value = 0
            dut.cont1_t.value = 0
            dut.cont1_dt.value = 0
        
        if cont2 is not None:
            dut.cont2_valid.value = 1
            dut.cont2_t.value = clamp_to_width(cont2[0], TASTINESS_WIDTH)
            dut.cont2_dt.value = clamp_to_width(cont2[1], TASTINESS_WIDTH)
        else:
            dut.cont2_valid.value = 0
            dut.cont2_t.value = 0
            dut.cont2_dt.value = 0
        
        dut.target_weight.value = clamp_to_width(target_weight, DATA_WIDTH)
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"  FAIL: Result is undefined (X/Z)")
            failed += 1
            continue
        
        result_fixed = int(dut.result.value)
        result_float = fixed_to_float(result_fixed, FRAC_BITS)
        
        # Read impossible flag
        impossible = 0
        if has_signal(dut, 'impossible'):
            impossible = int(dut.impossible.value)
        
        if impossible:
            if expected is None:
                cocotb.log.info(f"  PASS: Correctly determined impossible")
                passed += 1
            else:
                cocotb.log.error(f"  FAIL: Reported impossible but expected {expected}")
                failed += 1
        else:
            if expected is None:
                cocotb.log.error(f"  FAIL: Expected impossible but got {result_float}")
                failed += 1
            else:
                # Compare with tolerance
                tolerance = 1e-6
                if abs(result_float - expected) > tolerance:
                    cocotb.log.error(f"  FAIL: Expected {expected}, got {result_float} (diff={abs(result_float-expected)})")
                    failed += 1
                else:
                    cocotb.log.info(f"  PASS: result = {result_float:.9f}")
                    passed += 1
    
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
