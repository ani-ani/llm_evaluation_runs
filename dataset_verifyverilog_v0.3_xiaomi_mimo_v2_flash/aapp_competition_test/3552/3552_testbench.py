import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match the Verilog design
# ============================================================================
DATA_WIDTH_N = 8      # n bit width
DATA_WIDTH_M = 4      # m bit width
DATA_WIDTH_K = 8      # k bit width
RESULT_WIDTH = 16     # result bit width
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000     # Timeout for sequential computation

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

# Pre‑computed test cases: (n, m, k, expected_result)
# All values fit within the scaled limits.
test_cases = [
    (10, 4, 3, 27),   # Sample 1
    (12, 4, 3, 34),   # Additional
    (20, 3, 5, 54),   # Additional
    (5, 10, 8, 15),   # n <= m
    (9, 1, 3, 18),    # t=m not feasible
]

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_gnome_damage(dut):
    """Test the gnome damage module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Ensure required signals exist
    if not (has_signal(dut, 'n') and has_signal(dut, 'm') and has_signal(dut, 'k') and 
            has_signal(dut, 'result') and has_signal(dut, 'done') and has_signal(dut, 'start')):
        raise TestFailure("Missing required signals: n, m, k, result, done, start")
    
    passed = 0
    failed = 0
    
    for i, (n_val, m_val, k_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n_val}, m={m_val}, k={k_val} -> expected {expected}")
        
        # Write inputs (clamped to width)
        dut.n.value = clamp_to_width(n_val, DATA_WIDTH_N)
        dut.m.value = clamp_to_width(m_val, DATA_WIDTH_M)
        dut.k.value = clamp_to_width(k_val, DATA_WIDTH_K)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"  FAIL: Result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
