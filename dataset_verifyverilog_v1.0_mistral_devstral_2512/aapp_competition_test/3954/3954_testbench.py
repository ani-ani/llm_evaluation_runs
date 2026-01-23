import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 8          # Maximum array size
K = 4          # Maximum swaps
DATA_WIDTH = 16
FRAC_BITS = 8
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

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
# PROBLEM-SPECIFIC FUNCTIONS
# ============================================================================

def python_solve(n, k, a):
    """Reference Python implementation for the problem."""
    best = a[0]
    for l in range(n):
        for r in range(l, n):
            # Get inner and outer arrays
            inner = a[l:r+1]
            outer = a[:l] + a[r+1:]
            
            # Sort inner ascending, outer descending
            inner.sort()
            outer.sort(reverse=True)
            
            # Try swaps
            cur_sum = sum(inner)
            for i in range(min(k, len(inner), len(outer))):
                if outer[i] > inner[i]:
                    cur_sum += outer[i] - inner[i]
                else:
                    break
            
            if cur_sum > best:
                best = cur_sum
    
    return best

def scale_test_data(n, k, a):
    """Scale test data to fit HDL constraints."""
    # Scale n down to at most N=8
    n_scaled = min(n, N)
    # Use first n_scaled elements
    a_scaled = a[:n_scaled]
    # Scale k down to at most K=4
    k_scaled = min(k, K)
    return n_scaled, k_scaled, a_scaled

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_subarray_swaps(dut):
    """Test the max_subarray_swaps module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases from problem
    test_cases = [
        # (n, k, a, expected)
        (10, 2, [10, -1, 2, 2, 2, 2, 2, 2, -1, 10], 32),
        (5, 10, [-1, -1, -1, -1, -1], -1),
        (1, 10, [-1], -1),
        (1, 1, [-1], -1),
        (1, 1, [1], 1),
        (1, 10, [1], 1),
        (10, 1, [-1, 1, 1, 1, 1, 1, 1, 1, 1, 1], 9),
        # Additional scaled test cases
        (8, 4, [10, -1, 2, 2, 2, 2, 2, -1], 28),
        (8, 4, [-1, -1, -1, -1, -1, -1, -1, -1], -1),
        (8, 4, [5, 8, -2, 3, -4, 1, 6, -3], 18),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_orig, k_orig, a_orig, expected) in enumerate(test_cases):
        # Scale the test data
        n, k, a = scale_test_data(n_orig, k_orig, a_orig)
        
        # Skip if no elements
        if n == 0:
            continue
        
        dut._log.info(f"Test {i+1}: n={n_orig}->{n}, k={k_orig}->{k}, a={a_orig[:n]}, expected={expected}")
        
        try:
            # Write array elements individually
            for idx in range(N):
                if idx < n:
                    # Convert to fixed-point representation for signed values
                    val_fixed = from_signed(a[idx], DATA_WIDTH)
                    dut.a[idx].value = val_fixed
                else:
                    dut.a[idx].value = 0
            
            # Write k
            dut.k.value = k
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.max_sum.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_unsigned = int(dut.max_sum.value)
            result = to_signed(result_unsigned, DATA_WIDTH)
            
            # Scale expected result for fixed-point (if we used fixed-point)
            # For this problem, we're using integer arithmetic
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")