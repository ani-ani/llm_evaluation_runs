import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools

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
# PROBLEM‑SPECIFIC HELPERS
# ============================================================================

def is_unsorted(perm):
    """Check if a permutation is entirely unsorted."""
    n = len(perm)
    for k in range(n):
        # Check if perm[k] is sorted
        left_ok = all(perm[j] <= perm[k] for j in range(k))
        right_ok = all(perm[j] >= perm[k] for j in range(k+1, n))
        if left_ok and right_ok:
            return False
    return True

def count_entirely_unsorted(values):
    """Count distinct permutations that are entirely unsorted."""
    seen = set()
    count = 0
    for perm in itertools.permutations(values):
        if perm in seen:
            continue
        seen.add(perm)
        if is_unsorted(perm):
            count += 1
    return count

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_unsorted_checker(dut):
    """Test the unsorted_checker module."""
    
    # Start clock (10 ns period)
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases (n <= 8)
    test_cases = [
        (4, [0, 1, 2, 3]),      # Sample 1
        (5, [1, 1, 2, 1, 1]),  # Sample 2
        (3, [1, 2, 3]),        # Additional small case
        (8, [1, 2, 3, 4, 5, 6, 7, 8]), # Larger case
    ]
    
    for n, values in test_cases:
        # Compute expected count using Python
        expected = count_entirely_unsorted(values)
        dut._log.info(f"Testing {values}, expected unsorted count: {expected}")
        
        # Generate distinct permutations
        seen = set()
        actual = 0
        for perm in itertools.permutations(values):
            if perm in seen:
                continue
            seen.add(perm)
            
            # Write permutation to DUT
            dut.len.value = n
            for i in range(8):
                if i < n:
                    val = perm[i]
                else:
                    val = 0
                # Use getattr to access individual arr_0..arr_7 ports
                getattr(dut, f'arr_{i}').value = clamp_to_width(val, 8)
            
            # Start computation and wait for done
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.is_unsorted.value):
                raise TestFailure("is_unsorted is undefined (X/Z)")
            
            if int(dut.is_unsorted.value) == 1:
                actual += 1
        
        # Verify
        if actual != expected:
            raise TestFailure(f"For {values}: expected {expected}, got {actual}")
        else:
            dut._log.info(f"  PASS")
    
    dut._log.info("All tests passed!")
