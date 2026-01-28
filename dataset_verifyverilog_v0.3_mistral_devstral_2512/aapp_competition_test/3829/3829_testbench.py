import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8  # for m and n
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000  # enough for worst-case

# Fixed-point parameters
FRAC_BITS = 16
SCALE = 1 << FRAC_BITS  # 65536

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
# EXPECTED VALUE COMPUTATION (Python reference)
# ============================================================================

def compute_expected(m, n):
    """Compute expected maximum using the formula: E = m - Σ(i/m)^n for i=1 to m-1."""
    if m == 1:
        return 1.0
    total = 0.0
    for i in range(1, m):
        total += (i / m) ** n
    return m - total

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_expected_max(dut):
    """Test the expected_max module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (m, n, expected_value)
    test_cases = [
        (6, 1, 3.5),
        (6, 3, 4.958333333333),
        (2, 2, 1.75),
        (5, 4, 4.4336),
        (5, 8, 4.81477376),
        (3, 10, 2.982641534996),
        (3, 6, 2.910836762689),
        (1, 8, 1.0),
    ]
    
    passed = 0
    failed = 0
    
    for m, n, expected in test_cases:
        cocotb.log.info(f"Testing m={m}, n={n}, expected={expected}")
        
        # Write inputs
        dut.m.value = m
        dut.n.value = n
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error("  FAIL: result is undefined")
            failed += 1
            continue
        
        result_raw = int(dut.result.value)
        result_float = fixed_to_float(result_raw)
        
        # Compute expected in Python and convert to fixed-point for comparison
        expected_fixed = float_to_fixed(expected)
        expected_float = fixed_to_float(expected_fixed)
        
        # Allow small error due to fixed-point quantization
        error = abs(result_float - expected_float)
        if error > 0.001:  # tolerance 1e-3
            cocotb.log.error(f"  FAIL: result={result_float:.6f}, expected={expected_float:.6f}, error={error:.6f}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result={result_float:.6f}, expected={expected_float:.6f}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")