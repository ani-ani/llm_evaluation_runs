import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 3
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000
FRAC_BITS = 16  # Q16.16 fixed-point format

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

def fixed_to_float(fixed, frac_bits=FRAC_BITS):
    """Convert Q16.16 fixed-point to float."""
    return fixed / (1 << frac_bits)

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

async def start_computation(dut, n):
    """Start computation with given n."""
    dut.n.value = clamp_to_width(n, DATA_WIDTH)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_average_of_cube(dut):
    """Test the average of cubes module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, expected_float_result, description)
    test_cases = [
        (2, 4.5, "n=2: (1³+2³)/2 = 9/2 = 4.5"),
        (3, 12.0, "n=3: (1³+2³+3³)/3 = 36/3 = 12"),
        (1, 1.0, "n=1: (1³)/1 = 1"),
        (4, 25.0, "n=4: (1³+2³+3³+4³)/4 = 100/4 = 25"),
        (5, 45.0, "n=5: (1³+2³+3³+4³+5³)/5 = 225/5 = 45"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Start computation
            await start_computation(dut, n)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result_raw = int(dut.result.value)
            result_float = fixed_to_float(result_raw)
            
            # Allow small rounding error due to fixed-point
            error = abs(result_float - expected)
            
            # Check if within tolerance (0.01 for Q16.16)
            if error > 0.01:
                raise TestFailure(f"Expected {expected}, got {result_float} (raw={result_raw}, error={error})")
            
            cocotb.log.info(f"  PASS: result = {result_float:.6f} (Q16.16 raw = {result_raw})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_reset_behavior(dut):
    """Test that reset properly clears state."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Start a computation
    await start_computation(dut, 3)
    
    # Let it run for a few cycles
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    # Assert reset in the middle
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Check signals are reset
    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
        raise TestFailure("Done should be 0 after reset")
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Should be able to restart correctly
    await start_computation(dut, 2)
    await wait_for_done(dut)
    
    result_raw = int(dut.result.value)
    result_float = fixed_to_float(result_raw)
    
    if abs(result_float - 4.5) > 0.01:
        raise TestFailure(f"After reset restart, expected 4.5, got {result_float}")
    
    cocotb.log.info("  PASS: Reset behavior correct")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test maximum n (8)
    cocotb.log.info("Test: Maximum n=8")
    await start_computation(dut, 8)
    await wait_for_done(dut)
    
    result_raw = int(dut.result.value)
    result_float = fixed_to_float(result_raw)
    expected = 306.0  # (1+8+27+64+125+216+343+512)/8 = 1296/8 = 306
    
    if abs(result_float - expected) > 0.01:
        raise TestFailure(f"n=8: Expected {expected}, got {result_float}")
    
    cocotb.log.info(f"  PASS: n=8 result = {result_float:.6f}")
    
    # Test n=7
    await reset_dut(dut)
    cocotb.log.info("Test: n=7")
    await start_computation(dut, 7)
    await wait_for_done(dut)
    
    result_raw = int(dut.result.value)
    result_float = fixed_to_float(result_raw)
    expected = 169.0  # (1+8+27+64+125+216+343)/7 = 784/7 = 169
    
    if abs(result_float - expected) > 0.01:
        raise TestFailure(f"n=7: Expected {expected}, got {result_float}")
    
    cocotb.log.info(f"  PASS: n=7 result = {result_float:.6f}")
