import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
CLK_PERIOD_NS = 10
MAX_CYCLES = 100
RADIUS_SCALE = 256  # Scale for Q8.8 fixed-point input

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
# FIXED-POINT CONVERSION
# ============================================================================

def float_to_radius_fixed(value):
    """Convert radius to fixed-point (Q8.8) for input."""
    return int(value * RADIUS_SCALE)

def fixed_to_float(value, frac_bits=16):
    """Convert Q16.16 fixed-point to float."""
    return value / (1 << frac_bits)

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

async def start_computation(dut, radius):
    """Pulse start signal and set radius."""
    # Set radius input
    dut.radius.value = clamp_to_width(radius, 16)
    
    # Pulse start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sphere_volume(dut):
    """Test sphere volume calculation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (radius_float, expected_volume_float, description)
    test_cases = [
        (10, 4188.790204786391, "r=10"),
        (25, 65449.84694978735, "r=25"),
        (20, 33510.32163829113, "r=20"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (radius_float, expected_volume, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input radius: {radius_float}")
        cocotb.log.info(f"  Expected volume: {expected_volume}")
        
        try:
            # Convert radius to fixed-point
            radius_fixed = float_to_radius_fixed(radius_float)
            cocotb.log.info(f"  Radius fixed-point: {radius_fixed} (0x{radius_fixed:04X})")
            
            # Start computation
            await start_computation(dut, radius_fixed)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.volume.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_fixed = int(dut.volume.value)
            result_float = fixed_to_float(result_fixed)
            
            cocotb.log.info(f"  Result fixed-point: 0x{result_fixed:08X}")
            cocotb.log.info(f"  Result float: {result_float}")
            
            # Calculate error (allow 1% tolerance due to fixed-point approximation)
            error_pct = abs(result_float - expected_volume) / expected_volume * 100
            cocotb.log.info(f"  Error: {error_pct:.2f}%")
            
            if error_pct <= 1.0:  # 1% tolerance
                cocotb.log.info(f"  PASS")
                passed += 1
            else:
                raise TestFailure(f"Error {error_pct:.2f}% exceeds 1% tolerance")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")