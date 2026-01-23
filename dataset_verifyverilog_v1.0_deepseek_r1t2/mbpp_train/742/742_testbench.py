import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Q8.8 format: 8 integer, 8 fractional bits
FRAC_BITS = 8
INT_BITS = 8

# Q16.16 format for result
RESULT_INT_BITS = 16
RESULT_FRAC_BITS = 16

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def float_to_q88(f):
    """Convert float to Q8.8 fixed-point integer."""
    return int(f * (1 << FRAC_BITS))

def float_to_q1616(f):
    """Convert float to Q16.16 fixed-point integer."""
    return int(f * (1 << RESULT_FRAC_BITS))

def q1616_to_float(fixed):
    """Convert Q16.16 fixed-point to float."""
    return fixed / (1 << RESULT_FRAC_BITS)

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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tetrahedron_area(dut):
    """Test tetrahedron area calculation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (side_float, expected_result_float, description)
    test_cases = [
        (3.0, 15.588457268119894, "side=3"),
        (20.0, 692.8203230275509, "side=20"),
        (10.0, 173.20508075688772, "side=10"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (side_float, expected_float, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: {side_float}, Expected: {expected_float}")
        
        try:
            # Convert input to Q8.8 format
            side_q88 = float_to_q88(side_float)
            
            # Clamp to 16-bit width
            side_q88 = clamp_to_width(side_q88, 16)
            
            # Write input
            dut.side.value = side_q88
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result_raw = int(dut.result.value)
            
            # Convert result back to float
            result_float = q1616_to_float(result_raw)
            
            # Check with tolerance (fixed-point has rounding errors)
            tolerance = 0.01  # Allow 0.01 error for Q16.16 precision
            error = abs(result_float - expected_float)
            
            if error > tolerance:
                raise TestFailure(f"Expected {expected_float:.6f}, got {result_float:.6f}, error={error:.6f}")
            
            cocotb.log.info(f"  PASS: result = {result_float:.6f} (Q16.16: {result_raw})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")