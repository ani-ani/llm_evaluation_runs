import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
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

# ============================================================================
# FIXED-POINT CONVERSION HELPERS
# ============================================================================

# Fixed-point constants matching HDL
PI_Q16 = 205887          # 3.14159265 * 65536
ANGLE_360 = 92160        # 360 * 256
INV_360_Q16 = 182        # 65536 / 360

def float_to_q8_8(f):
    """Convert float to Q8.8 fixed-point (8 integer, 8 fractional bits)."""
    return int(f * 256)

def float_to_q16_16(f):
    """Convert float to Q16.16 fixed-point (16 integer, 16 fractional bits)."""
    return int(f * 65536)

def q16_16_to_float(q):
    """Convert Q16.16 fixed-point back to float."""
    return q / 65536.0

def compute_expected(r, a):
    """Compute expected result using Python math."""
    if a > 360:
        return None
    # Compute in fixed-point to match HDL
    r_q8 = float_to_q8_8(r)
    a_q8 = float_to_q8_8(a)
    
    # r_squared = (r_q8 * r_q8) >> 8
    r_squared = (r_q8 * r_q8) >> 8
    
    # pi_r_sq = (PI_Q16 * r_squared) >> 16
    pi_r_sq = (PI_Q16 * r_squared) >> 16
    
    # angle_norm = (a_q8 * INV_360_Q16) >> 8
    angle_norm = (a_q8 * INV_360_Q16) >> 8
    
    # result = (pi_r_sq * angle_norm) >> 16
    result = (pi_r_sq * angle_norm) >> 16
    
    # Convert back to float for comparison
    return q16_16_to_float(result)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for _ in range(3):
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

async def start_computation(dut, radius, angle):
    """Start computation with given inputs."""
    # Convert to fixed-point
    r_q8 = float_to_q8_8(radius)
    a_q8 = float_to_q8_8(angle)
    
    # Set inputs
    dut.radius.value = r_q8
    dut.angle.value = a_q8
    
    # Pulse start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sector_area(dut):
    """Test sector area calculation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        (4.0, 45.0, "Test 1: r=4, a=45"),
        (9.0, 45.0, "Test 2: r=9, a=45"),
        (9.0, 361.0, "Test 3: r=9, a=361 (invalid)"),
        (1.0, 0.0, "Test 4: r=1, a=0"),
        (1.0, 360.0, "Test 5: r=1, a=360"),
        (5.5, 180.0, "Test 6: r=5.5, a=180"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (radius, angle, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: radius={radius}, angle={angle}")
        
        try:
            # Start computation
            await start_computation(dut, radius, angle)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read outputs
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            if not is_value_defined(dut.invalid.value):
                raise TestFailure("Invalid signal is undefined (X/Z)")
            
            result_q16 = int(dut.result.value)
            invalid = int(dut.invalid.value)
            
            # Compute expected
            expected = compute_expected(radius, angle)
            
            # Verify
            if angle > 360:
                # Should be invalid
                if invalid != 1:
                    raise TestFailure(f"Expected invalid=1, got {invalid}")
                cocotb.log.info(f"  PASS: Correctly flagged as invalid")
            else:
                # Should be valid
                if invalid != 0:
                    raise TestFailure(f"Expected invalid=0, got {invalid}")
                
                # Compare results (allow small rounding error)
                result_float = q16_16_to_float(result_q16)
                
                # Allow 0.5% tolerance for fixed-point rounding
                tolerance = abs(expected * 0.005)
                if tolerance < 0.001:
                    tolerance = 0.001
                
                if abs(result_float - expected) > tolerance:
                    raise TestFailure(
                        f"Expected {expected:.6f}, got {result_float:.6f} "
                        f"(diff={abs(result_float - expected):.6f}, tolerance={tolerance:.6f})"
                    )
                
                cocotb.log.info(f"  Result: {result_float:.6f} (Q16.16={result_q16})")
                cocotb.log.info(f"  Expected: {expected:.6f}")
                cocotb.log.info(f"  PASS")
            
            passed += 1
            
            # Wait one cycle before next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")