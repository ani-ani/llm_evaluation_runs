import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants for fixed-point conversion
PI_SCALED = 205887  # 3.1416 * 65536
SCALE_FACTOR = 256  # Q8.8 to Q16.16 conversion
FRAC_BITS = 16
MAX_VAL_16 = 65280
MAX_VAL_32 = 0xFFFFFFFF

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def float_to_fixed_point(value, frac=16):
    return int(value * (1 << frac))

def compute_surface_area_fixed(r, h):
    """Compute surface area with fixed-point arithmetic"""
    # r and h are in Q8.8 format (scaled by 256)
    # Convert to Q16.16 for calculation
    r_scaled = r * SCALE_FACTOR
    h_scaled = h * SCALE_FACTOR
    
    # surface = 2 * pi * r * (r + h)
    # Use 32-bit intermediate values
    r_plus_h = r_scaled + h_scaled
    pi_r = (PI_SCALED * r_scaled) >> FRAC_BITS  # Q16.16 * Q16.16 -> Q32.32, shift to Q16.16
    two_pi_r = pi_r << 1  # Multiply by 2
    result = (two_pi_r * r_plus_h) >> FRAC_BITS  # Q32.32 * Q16.16 -> Q48.48, shift to Q16.16
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cylinder_surface_area(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Test cases with Q8.8 input values
    test_cases = [
        (10, 5, 942.45, "r=10, h=5"),
        (4, 5, 226.19, "r=4, h=5"),
        (4, 10, 351.85, "r=4, h=10")
    ]
    
    passed = 0
    failed = 0
    
    for i, (r_val, h_val, exp_float, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Convert to Q8.8 format (scaled by 256)
            r_q8 = int(r_val * 256)
            h_q8 = int(h_val * 256)
            
            # Set input values
            dut.r.value = clamp_to_width(r_q8, 16)
            dut.h.value = clamp_to_width(h_q8, 16)
            
            # Start calculation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result_q16 = int(dut.result.value)
            
            # Convert expected value to Q16.16 format
            exp_q16 = float_to_fixed_point(exp_float, 16)
            
            # Allow some tolerance due to pi approximation
            tolerance = 0.01 * (1 << 16)  # 1% tolerance
            
            if abs(result_q16 - exp_q16) > tolerance:
                raise TestFailure(f"Expected {exp_q16} (≈{exp_float}), got {result_q16} (≈{result_q16/(1<<16):.2f})")
            
            cocotb.log.info(f"Result: {result_q16} (≈{result_q16/(1<<16):.2f})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Prepare for next test
        await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cylinder_edge_cases(dut):
    """Test edge cases and maximum values"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    edge_cases = [
        (1, 1, "Minimum values"),
        (255, 255, "Maximum values")
    ]
    
    for i, (r_val, h_val, desc) in enumerate(edge_cases):
        cocotb.log.info(f"Edge case {i+1}: {desc}")
        try:
            # Convert to Q8.8
            r_q8 = int(r_val * 256)
            h_q8 = int(h_val * 256)
            
            dut.r.value = clamp_to_width(r_q8, 16)
            dut.h.value = clamp_to_width(h_q8, 16)
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result_q16 = int(dut.result.value)
            exp_float = surfacearea_cylinder(r_val, h_val)
            exp_q16 = float_to_fixed_point(exp_float, 16)
            
            tolerance = 0.01 * (1 << 16)
            if abs(result_q16 - exp_q16) > tolerance:
                raise TestFailure(f"Expected ≈{exp_float}, got {result_q16/(1<<16):.2f}")
            
            cocotb.log.info(f"Result: {result_q16/(1<<16):.2f} (within tolerance)")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            raise

# Reference function for expected values
def surfacearea_cylinder(r, h):
    surfacearea = ((2 * 3.1415 * r * r) + (2 * 3.1415 * r * h))
    return surfacearea