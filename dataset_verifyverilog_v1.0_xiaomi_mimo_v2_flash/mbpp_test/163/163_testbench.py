import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
SIDES_WIDTH = 4
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

def float_to_q16_16(f):
    """Convert float to Q16.16 fixed-point integer."""
    return int(f * 65536.0)

def q16_16_to_float(q):
    """Convert Q16.16 fixed-point to float."""
    return q / 65536.0

def float_to_q8_8(f):
    """Convert float to Q8.8 fixed-point integer."""
    return int(f * 256.0)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'sides'):
        dut.sides.value = 0
    if has_signal(dut, 'length'):
        dut.length.value = 0
    
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

async def start_computation(dut, sides, length):
    """Set inputs, pulse start, and wait for completion."""
    # Set inputs
    dut.sides.value = sides
    dut.length.value = float_to_q8_8(length)
    
    # Pulse start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_polygon_area(dut):
    """Test polygon area calculation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (sides, length_in_float, expected_area_float)
    test_cases = [
        (4, 20.0, 400.0),      # Square
        (10, 15.0, 1731.197),  # Decagon
        (9, 7.0, 302.909),     # Nonagon
    ]
    
    passed = 0
    failed = 0
    
    for i, (sides, length, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {sides}-sided polygon, length={length}")
        
        try:
            # Start computation
            await start_computation(dut, sides, length)
            
            # Check error flag
            if has_signal(dut, 'error') and is_value_defined(dut.error.value):
                if int(dut.error.value) == 1:
                    raise TestFailure(f"Error flag asserted for valid input (sides={sides})")
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_q16_16 = int(dut.result.value)
            result_float = q16_16_to_float(result_q16_16)
            
            # Verify with tolerance
            tolerance = 0.01  # Allow 1% error due to fixed-point precision
            rel_error = abs(result_float - expected) / max(abs(expected), 1e-9)
            
            if rel_error > tolerance:
                raise TestFailure(
                    f"Expected {expected:.4f}, got {result_float:.4f} "
                    f"(Q16.16: {result_q16_16}, error: {rel_error:.4f})"
                )
            
            cocotb.log.info(f"  PASS: area = {result_float:.4f} (expected {expected:.4f})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Test invalid input (sides < 3)
    cocotb.log.info("Test: Invalid input (sides=2)")
    try:
        await start_computation(dut, 2, 10.0)
        
        if has_signal(dut, 'error') and is_value_defined(dut.error.value):
            if int(dut.error.value) == 1:
                cocotb.log.info("  PASS: Error flag correctly asserted")
                passed += 1
            else:
                cocotb.log.error("  FAIL: Error flag not asserted for invalid input")
                failed += 1
        else:
            # No error signal, check result is 0 or invalid
            if is_value_defined(dut.result.value):
                result = int(dut.result.value)
                if result == 0:
                    cocotb.log.info("  PASS: Result is 0 for invalid input")
                    passed += 1
                else:
                    cocotb.log.error(f"  FAIL: Non-zero result {result} for invalid input")
                    failed += 1
            else:
                cocotb.log.error("  FAIL: Result undefined for invalid input")
                failed += 1
    except TestFailure as e:
        cocotb.log.error(f"  FAIL: {e}")
        failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
