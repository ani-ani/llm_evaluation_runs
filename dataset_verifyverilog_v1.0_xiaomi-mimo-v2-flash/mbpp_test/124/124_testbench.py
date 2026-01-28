import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 500
FIXED_SHIFT = 16

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    if val >= (1 << (bits-1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    min_val = -(1 << bits)
    if v > max_val:
        return max_val
    if v < min_val:
        return min_val
    return v

# Fixed-point conversion
def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    if v >= (1 << 31):  # Handle overflow
        v = v - (1 << 32)
    return v / (1 << frac)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def test_case(a_val, b_val, expected_angle):
    """Calculate expected angle using atan2(b, a)"""
    # Python's math.atan2(y, x) returns atan2(imag, real)
    angle = math.atan2(b_val, a_val)
    # Normalize to [-π, π] (already done by atan2)
    return float_to_fixed(angle, FIXED_SHIFT)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_complex_angle_calculator(dut):
    # Check for required signals
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module missing 'clk' signal")
    if not has_signal(dut, 'rst_n'):
        raise TestFailure("Module missing 'rst_n' signal")
    if not has_signal(dut, 'start'):
        raise TestFailure("Module missing 'start' signal")
    if not has_signal(dut, 'a'):
        raise TestFailure("Module missing 'a' signal")
    if not has_signal(dut, 'b'):
        raise TestFailure("Module missing 'b' signal")
    if not has_signal(dut, 'angle'):
        raise TestFailure("Module missing 'angle' signal")
    if not has_signal(dut, 'done'):
        raise TestFailure("Module missing 'done' signal")
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from Python examples
    test_cases = [
        # (a, b, expected_radians)
        (0, 1, 1.5707963267948966),      # 0 + i*1
        (2, 1, 0.4636476090008061),      # 2 + i*1
        (0, 2, 1.5707963267948966),      # 0 + i*2
    ]
    
    for i, (a_real, b_imag, expected_rad) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: a={a_real}, b={b_imag}, expected={expected_rad:.6f}")
        
        # Convert to Q8.8 format
        a_fixed = int(a_real * 256)
        b_fixed = int(b_imag * 256)
        
        # Clamp to 16-bit signed range
        a_clamped = clamp_to_width(a_fixed, DATA_WIDTH)
        b_clamped = clamp_to_width(b_fixed, DATA_WIDTH)
        
        # Drive inputs
        dut.a.value = from_signed(a_clamped, DATA_WIDTH)
        dut.b.value = from_signed(b_clamped, DATA_WIDTH)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.angle.value):
            raise TestFailure("Angle output undefined")
        
        angle_val = int(dut.angle.value)
        angle_signed = to_signed(angle_val, 32)
        angle_float = fixed_to_float(angle_signed, FIXED_SHIFT)
        
        # Verify with tolerance (0.01 radians)
        tolerance = 0.01
        if abs(angle_float - expected_rad) > tolerance:
            raise TestFailure(f"Test {i+1} failed: expected {expected_rad:.6f}, got {angle_float:.6f}, diff={abs(angle_float-expected_rad):.6f}")
        
        cocotb.log.info(f"  Result: {angle_float:.6f} rad, PASS")
        
        await RisingEdge(dut.clk)
    
    # Additional edge case tests
    cocotb.log.info("Testing edge cases...")
    edge_cases = [
        (1, 0, 0.0),      # 0 degrees
        (-1, 0, math.pi), # 180 degrees
        (0, 0, 0.0),      # Zero vector
        (10, 10, 0.7853981633974483),  # 45 degrees
    ]
    
    for a_real, b_imag, expected_rad in edge_cases:
        a_fixed = int(a_real * 256)
        b_fixed = int(b_imag * 256)
        a_clamped = clamp_to_width(a_fixed, DATA_WIDTH)
        b_clamped = clamp_to_width(b_fixed, DATA_WIDTH)
        
        dut.a.value = from_signed(a_clamped, DATA_WIDTH)
        dut.b.value = from_signed(b_clamped, DATA_WIDTH)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        
        angle_val = int(dut.angle.value)
        angle_signed = to_signed(angle_val, 32)
        angle_float = fixed_to_float(angle_signed, FIXED_SHIFT)
        
        tolerance = 0.02  # Slightly relaxed for edge cases
        if abs(angle_float - expected_rad) > tolerance:
            raise TestFailure(f"Edge case failed: a={a_real}, b={b_imag}, expected {expected_rad:.6f}, got {angle_float:.6f}")
        
        await RisingEdge(dut.clk)
    
    cocotb.log.info("All tests passed!")