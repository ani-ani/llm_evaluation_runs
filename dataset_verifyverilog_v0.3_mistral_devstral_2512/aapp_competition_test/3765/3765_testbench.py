import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
MULT_WIDTH = 18
RESULT_WIDTH = 5
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
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_find_min_extensions(dut):
    """Test the find_min_extensions module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (a, b, h, w, multipliers, expected_k)
    # We take top 8 multipliers from input, pad with 1s if needed
    test_cases = [
        # Example 1: 3 3 2 4 4
        # Multipliers: [2, 5, 4, 10] -> top 8: [10, 5, 4, 2, 1, 1, 1, 1]
        (3, 3, 2, 4, [10, 5, 4, 2, 1, 1, 1, 1], 1),
        # Example 2: 3 3 3 3 5
        # Multipliers: [2, 3, 5, 4, 2] -> top 8: [5, 4, 3, 2, 2, 1, 1, 1]
        (3, 3, 3, 3, [5, 4, 3, 2, 2, 1, 1, 1], 0),
        # Example 3: 5 5 1 2 3
        # Multipliers: [2, 2, 3] -> top 8: [3, 2, 2, 1, 1, 1, 1, 1]
        (5, 5, 1, 2, [3, 2, 2, 1, 1, 1, 1, 1], -1),
        # Example 4: 3 4 1 1 3
        # Multipliers: [2, 3, 2] -> top 8: [3, 2, 2, 1, 1, 1, 1, 1]
        (3, 4, 1, 1, [3, 2, 2, 1, 1, 1, 1, 1], 3),
        # Additional test: No extension needed
        (10, 20, 10, 20, [1, 1, 1, 1, 1, 1, 1, 1], 0),
        # Additional test: Needs 2 extensions
        (20, 20, 5, 5, [2, 2, 3, 1, 1, 1, 1, 1], 2),
    ]
    
    for i, (a, b, h, w, multipliers, expected_k) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: a={a}, b={b}, h={h}, w={w}")
        dut._log.info(f"  Multipliers: {multipliers}")
        
        # Set inputs
        dut.a.value = clamp_to_width(a, DATA_WIDTH)
        dut.b.value = clamp_to_width(b, DATA_WIDTH)
        dut.h.value = clamp_to_width(h, DATA_WIDTH)
        dut.w.value = clamp_to_width(w, DATA_WIDTH)
        
        # Set multipliers (8 values)
        for j in range(8):
            mult_name = f'mult{j}'
            if has_signal(dut, mult_name):
                getattr(dut, mult_name).value = clamp_to_width(multipliers[j], MULT_WIDTH)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.k.value):
            raise TestFailure(f"Test {i+1}: k is undefined (X/Z)")
        
        result_k = int(dut.k.value)
        
        # Convert from 5-bit unsigned: if result_k == 31 (5'b11111), then it's -1
        if result_k == 31:
            result_k = -1
        
        if result_k != expected_k:
            raise TestFailure(f"Test {i+1}: Expected {expected_k}, got {result_k}")
        
        dut._log.info(f"  PASS: k = {result_k}")
        
        # Reset for next test
        await reset_dut(dut)
    
    dut._log.info("All tests passed!")