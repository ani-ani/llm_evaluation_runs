import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 150

def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def clamp_to_width(v, bits):
    min_val = -(1 << (bits-1))
    max_val = (1 << (bits-1)) - 1
    return min(max_val, max(min_val, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

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

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

async def send_inputs(dut, real, imag):
    # Clamp inputs to 8-bit signed
    real_clamped = clamp_to_width(real, 8)
    imag_clamped = clamp_to_width(imag, 8)
    
    if has_signal(dut, 'real_in'):
        # Handle signed extension if Verilog expects unsigned, but spec says signed
        # In Python, we just assign the integer; cocotb handles 2's complement
        dut.real_in.value = real_clamped & 0xFF  # 8-bit value
    if has_signal(dut, 'imag_in'):
        dut.imag_in.value = imag_clamped & 0xFF
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
    await RisingEdge(dut.clk)
    if has_signal(dut, 'start'):
        dut.start.value = 0

async def read_results(dut):
    if has_signal(dut, 'magnitude') and is_value_defined(dut.magnitude.value):
        mag = int(dut.magnitude.value)
        # Sign-extend 32-bit if needed (assuming Q16.16 signed)
        if mag & 0x80000000:
            mag -= 0x100000000
    else:
        mag = 0
    
    if has_signal(dut, 'angle') and is_value_defined(dut.angle.value):
        ang = int(dut.angle.value)
        if ang & 0x80000000:
            ang -= 0x100000000
    else:
        ang = 0
    
    return mag, ang

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_complex_to_polar(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: just assign and read
        pass
    
    # Test cases from prompt
    test_cases = [
        (1, 0, 1.0, 0.0, "Positive real, zero imag"),
        (4, 0, 4.0, 0.0, "Larger real, zero imag"),
        (5, 0, 5.0, 0.0, "Another real, zero imag"),
        (0, 1, 1.0, math.pi/2, "Positive imag, zero real"),
        (-1, 0, 1.0, math.pi, "Negative real, zero imag"),
        (1, 1, math.sqrt(2), math.pi/4, "Both positive"),
        (0, 0, 0.0, 0.0, "Zero"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (real_in, imag_in, exp_mag, exp_ang, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Send inputs
            if is_seq:
                await send_inputs(dut, real_in, imag_in)
                await wait_for_done(dut)
            else:
                # Combinational: set inputs
                real_clamped = clamp_to_width(real_in, 8)
                imag_clamped = clamp_to_width(imag_in, 8)
                if has_signal(dut, 'real_in'):
                    dut.real_in.value = real_clamped & 0xFF
                if has_signal(dut, 'imag_in'):
                    dut.imag_in.value = imag_clamped & 0xFF
                await Timer(10, units='ns')  # Propagation delay
            
            # Read results
            mag_fp, ang_fp = await read_results(dut)
            
            # Convert to float for comparison
            mag_meas = fixed_to_float(mag_fp)
            ang_meas = fixed_to_float(ang_fp)
            
            # Normalize angle to -π to π for comparison
            # Note: atan2 should output in this range
            if ang_meas > math.pi:
                ang_meas -= 2*math.pi
            elif ang_meas < -math.pi:
                ang_meas += 2*math.pi
            
            # Allow tolerance due to fixed-point approximation
            MAG_TOL = 0.01  # ~1/256 in fixed-point
            ANG_TOL = 0.01  # ~1/256 in Q16.16
            
            if abs(mag_meas - exp_mag) > MAG_TOL:
                raise TestFailure(f"Magnitude mismatch: expected {exp_mag:.4f}, got {mag_meas:.4f}")
            if abs(ang_meas - exp_ang) > ANG_TOL:
                # Allow π for negative real (angle=π)
                if abs(exp_ang - math.pi) < 0.01 and abs(ang_meas - math.pi) < ANG_TOL:
                    pass
                else:
                    raise TestFailure(f"Angle mismatch: expected {exp_ang:.4f}, got {ang_meas:.4f}")
            
            cocotb.log.info(f"  PASS: mag={mag_meas:.4f}, ang={ang_meas:.4f}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")