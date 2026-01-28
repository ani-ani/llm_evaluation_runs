import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16          # Input radius is Q8.8 (16 bits)
RESULT_WIDTH = 32        # Output circumference is Q16.16 (32 bits)
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Fixed-point format parameters
INT_BITS_IN = 8          # Integer bits in input (radius)
FRAC_BITS_IN = 8         # Fractional bits in input
INT_BITS_OUT = 16        # Integer bits in output
FRAC_BITS_OUT = 16       # Fractional bits in output

# Pi constant in Q16.16 format
PI_Q16_16 = 205887       # 3.141592653589793 * 65536

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

def float_to_q8_8(f):
    """Convert float to Q8.8 format (8 integer, 8 fractional bits)."""
    return int(f * 256)

def q16_16_to_float(q):
    """Convert Q16.16 format back to float."""
    return q / 65536.0

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(2):
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
async def test_circle_circumference(dut):
    """Test circle circumference calculation with fixed-point arithmetic."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (radius_float, expected_circumference_float)
    test_cases = [
        (10.0, 62.830000000000005),
        (5.0, 31.415000000000003),
        (4.0, 25.132),
    ]
    
    passed = 0
    failed = 0
    
    for i, (radius_float, expected_float) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: radius = {radius_float}")
        
        try:
            # Convert radius to Q8.8
            radius_q8_8 = float_to_q8_8(radius_float)
            
            cocotb.log.info(f"  Radius Q8.8: {radius_q8_8} (0x{radius_q8_8:04X})")
            
            # Assign inputs
            dut.radius.value = radius_q8_8
            dut.start.value = 0
            
            # Wait a bit for inputs to settle
            await Timer(10, units='ns')
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.circumference.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_q16_16 = int(dut.circumference.value)
            result_float = q16_16_to_float(result_q16_16)
            
            cocotb.log.info(f"  Result Q16.16: {result_q16_16} (0x{result_q16_16:08X})")
            cocotb.log.info(f"  Result float: {result_float:.6f}")
            cocotb.log.info(f"  Expected: {expected_float:.6f}")
            
            # Check if result is close to expected (with tolerance for fixed-point)
            abs_diff = abs(result_float - expected_float)
            rel_diff = abs_diff / max(abs(expected_float), 1e-9)
            
            if rel_diff > 0.001:
                raise TestFailure(
                    f"Expected {expected_float:.6f}, got {result_float:.6f} "
                    f"(diff: {rel_diff:.6f}, tolerance: 0.001)"
                )
            
            cocotb.log.info(f"  PASS: Match within tolerance")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")