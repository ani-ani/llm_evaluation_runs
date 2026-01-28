import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
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
# FIXED-POINT CONVERSION
# ============================================================================

def float_to_q88(value):
    """Convert float to Q8.8 fixed-point format."""
    return int(value * 256)

def float_to_q1616(value):
    """Convert float to Q16.16 fixed-point format."""
    return int(value * 65536)

def q1616_to_float(value):
    """Convert Q16.16 fixed-point to float."""
    return value / 65536.0

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
async def test_cylinder_volume(dut):
    """Test cylinder volume calculation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (radius, height, expected_volume)
    # Converted to Q8.8 fixed-point for inputs
    # Expected volume in Q16.16
    test_cases = [
        (10.0, 5.0, 1570.75),
        (4.0, 5.0, 251.32),
        (4.0, 10.0, 502.64),
    ]
    
    passed = 0
    failed = 0
    
    for i, (radius, height, expected_vol) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: r={radius}, h={height}, expected={expected_vol}")
        
        try:
            # Convert to fixed-point
            radius_fp = float_to_q88(radius)
            height_fp = float_to_q88(height)
            expected_fp = float_to_q1616(expected_vol)
            
            # Set inputs
            dut.radius.value = clamp_to_width(radius_fp, DATA_WIDTH)
            dut.height.value = clamp_to_width(height_fp, DATA_WIDTH)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.volume.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_fp = int(dut.volume.value)
            result_float = q1616_to_float(result_fp)
            
            # Check with tolerance
            tolerance = abs(expected_vol * 0.01)  # 1% tolerance
            if abs(result_float - expected_vol) > tolerance:
                raise TestFailure(
                    f"Expected {expected_vol} (0x{expected_fp:08X}), "
                    f"got {result_float} (0x{result_fp:08X})"
                )
            
            cocotb.log.info(f"  PASS: volume = {result_float:.4f}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")