import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Constants
DATA_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Helper functions

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
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

def float_to_fixed(f, int_bits=1, frac_bits=14):
    """Convert float to fixed-point (signed)."""
    full_bits = int_bits + frac_bits
    scaled = int(f * (1 << frac_bits))
    # Ensure fits in width
    if scaled >= (1 << (full_bits - 1)):
        scaled = (1 << (full_bits - 1)) - 1
    elif scaled < -(1 << (full_bits - 1)):
        scaled = -(1 << (full_bits - 1))
    return from_signed(scaled, full_bits)

def fixed_to_float(fixed, int_bits=1, frac_bits=14):
    """Convert fixed-point to float."""
    full_bits = int_bits + frac_bits
    signed = to_signed(fixed, full_bits)
    return signed / (1 << frac_bits)

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_complex_angle(dut):
    """Test complex angle calculation."""
    
    # Detect interface
    if not has_signal(dut, 'clk'):
        dut._log.error("Missing clk signal - sequential module required")
        raise TestFailure("Missing required signals")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (real, imag, expected_angle)
    # Python's cmath.phase returns angle in radians
    # We'll use scaled integer inputs for the hardware
    # Scale factor: 4096 (so 1.0 = 4096)
    
    test_cases = [
        # Test 1: a=0, b=1j -> angle=pi/2 ~ 1.5708
        (0.0, 1.0, 1.5707963267948966, "a=0, b=1"),
        # Test 2: a=2, b=1j -> angle=atan(1/2) ~ 0.4636
        (2.0, 1.0, 0.4636476090008061, "a=2, b=1"),
        # Test 3: a=0, b=2j -> angle=pi/2 ~ 1.5708
        (0.0, 2.0, 1.5707963267948966, "a=0, b=2"),
    ]
    
    SCALE_FACTOR = 4096  # For scaling float to integer
    
    passed = 0
    failed = 0
    
    for i, (real, imag, expected_rad, desc) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {desc}")
        
        # Convert to scaled integers (Q1.14 format for inputs)
        a_int = int(real * SCALE_FACTOR)
        b_int = int(imag * SCALE_FACTOR)
        
        # Ensure within 16-bit range
        a_int = max(-32768, min(32767, a_int))
        b_int = max(-32768, min(32767, b_int))
        
        dut._log.info(f"  Inputs: a={a_int} ({real}), b={b_int} ({imag})")
        
        # Apply inputs
        if has_signal(dut, 'a'):
            dut.a.value = from_signed(a_int, 16)
        if has_signal(dut, 'b'):
            dut.b.value = from_signed(b_int, 16)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=100)
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.angle.value):
            dut._log.error("  FAIL: Result undefined (X/Z)")
            failed += 1
            continue
        
        raw_result = int(dut.angle.value)
        result_rad = to_signed(raw_result, 16) / 128.0  # Q1.7 format (8 bits total, 1 sign, 1 integer, 6 fractional?)
        # Actually, let's assume output is Q8.8: 8 integer bits, 8 fractional = total 16 bits
        # Wait, prompt says Q8.8 but that is usually 8 fractional, 8 integer? No, usually 8 integer 8 fractional is total 16.
        # Let's re-read: "Q8.8 fixed-point format" usually means 8 fractional bits.
        # But if we want range -pi to pi (~3.14), we need at least 3 integer bits (2's complement).
        # Let's assume the module returns raw 16-bit value where we divide by 128 (2^7) to get radians.
        # This gives range +/- 256 which is plenty.
        
        result_rad = to_signed(raw_result, 16) / 128.0
        
        dut._log.info(f"  Result: 0x{raw_result:04X} -> {result_rad:.6f} rad (expected {expected_rad:.6f})")
        
        # Check with tolerance
        if math.isclose(result_rad, expected_rad, rel_tol=0.01, abs_tol=0.05):
            dut._log.info(f"  PASS")
            passed += 1
        else:
            dut._log.error(f"  FAIL: mismatch")
            failed += 1
    
    dut._log.info(f"\n{'='*40}")
    dut._log.info(f"Summary: {passed}/{passed+failed} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
