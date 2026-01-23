import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
DATA_WIDTH = 32
MAX_PRESCRIPTIONS = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# MANDATORY HELPER FUNCTIONS

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# SEQUENTIAL MODULE HELPERS

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_enable.value = 0
    dut.load_done.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_prescription(dut, drop_time, p_type, fill_time):
    """Load one prescription."""
    dut.load_drop_time.value = drop_time
    dut.load_type.value = 1 if p_type == 'S' else 0
    dut.load_fill_time.value = fill_time
    dut.load_enable.value = 1
    await RisingEdge(dut.clk)
    dut.load_enable.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pharmacy(dut):
    """Test pharmacy prescription scheduling"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (prescriptions, expected_o, expected_r)
    # Using scaled-down versions of the example test cases
    test_cases = [
        (
            [
                (1, 'R', 4),
                (2, 'R', 2),
                (3, 'R', 2),
                (4, 'S', 2),
                (5, 'S', 1),
            ],
            1.500000, 2.666667  # T=3 case
        ),
        (
            [
                (1, 'R', 4),
                (2, 'R', 2),
                (3, 'R', 2),
                (4, 'S', 2),
                (5, 'S', 1),
            ],
            1.500000, 3.666667  # T=2 case
        ),
        (
            [
                (1, 'R', 4),
                (2, 'R', 2),
                (3, 'R', 2),
                (4, 'S', 2),
                (5, 'S', 1),
            ],
            3.000000, 7.000000  # T=1 case
        ),
    ]
    
    for i, (prescriptions, expected_o, expected_r) in enumerate(test_cases):
        cocotb.log.info(f"\nTest case {i+1}")
        
        # Load prescriptions
        for drop, ptype, fill in prescriptions:
            await load_prescription(dut, drop, ptype, fill)
        
        # Mark loading complete
        dut.load_done.value = 1
        await RisingEdge(dut.clk)
        dut.load_done.value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read results
        if not all(is_value_defined(getattr(dut, sig).value) for sig in ['sum_S', 'sum_R', 'count_S', 'count_R']):
            raise TestFailure(f"Output signals undefined")
        
        sum_S = int(dut.sum_S.value)
        sum_R = int(dut.sum_R.value)
        count_S = int(dut.count_S.value)
        count_R = int(dut.count_R.value)
        
        # Compute averages
        result_o = (sum_S / count_S) if count_S > 0 else 0.0
        result_r = (sum_R / count_R) if count_R > 0 else 0.0
        
        # Compare with expected (with tolerance)
        tol = 1e-6
        if abs(result_o - expected_o) > tol or abs(result_r - expected_r) > tol:
            raise TestFailure(
                f"Test {i+1} failed:\n"
                f"  Expected O={expected_o:.6f}, R={expected_r:.6f}\n"
                f"  Got      O={result_o:.6f}, R={result_r:.6f}\n"
                f"  Sum_S={sum_S}, Count_S={count_S}, Sum_R={sum_R}, Count_R={count_R}"
            )
        
        cocotb.log.info(f"  PASS: O={result_o:.6f}, R={result_r:.6f}")
        
        # Reset for next test
        await reset_dut(dut)
    
    cocotb.log.info("\nAll tests passed!")
