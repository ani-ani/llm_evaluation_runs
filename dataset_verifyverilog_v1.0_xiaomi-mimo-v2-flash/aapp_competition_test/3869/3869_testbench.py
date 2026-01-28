import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
from math import sin, cos, tan, radians, pi

CLK_NS = 10

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def float_to_q8_8(f):
    return int(f * 256 + 0.5)

def float_to_q16_16(f):
    return int(f * 65536 + 0.5)

def q16_16_to_float(val):
    return val / 65536.0

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=600):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_intersection_area(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (w, h, alpha_deg, expected_area_approx)
    # Input values are scaled to Q8.8 (multiply by 256)
    # Expected area computed in Python and scaled to Q16.16
    test_cases = [
        (1.0, 1.0, 45, 0.828427125),
        (6.0, 4.0, 30, 19.668384925),
        (100.0, 100.0, 0, 10000.0),
        (100.0, 100.0, 90, 10000.0),
        (2.0, 100.0, 90, 4.0),
    ]
    
    passed = 0
    failed = 0
    
    for w_f, h_f, alpha_f, expected_f in test_cases:
        cocotb.log.info(f"Test: w={w_f}, h={h_f}, alpha={alpha_f}")
        
        # Scale inputs
        w_q8 = float_to_q8_8(w_f)
        h_q8 = float_to_q8_8(h_f)
        alpha_q8 = int(alpha_f)  # Direct degrees
        exp_area_q16 = float_to_q16_16(expected_f)
        
        # Assign inputs
        dut.w_i.value = clamp_to_width(w_q8, 16)
        dut.h_i.value = clamp_to_width(h_q8, 16)
        dut.alpha_i.value = clamp_to_width(alpha_q8, 8)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.area_o.value):
                raise TestFailure("Result undefined")
                
            result_val = int(dut.area_o.value)
            # Convert to signed if needed (assuming Q16.16 positive)
            result_float = q16_16_to_float(result_val)
            expected_float = q16_16_to_float(exp_area_q16)
            
            # Check tolerance: relative or absolute error < 1e-4 (scaled for fixed point)
            # Q16.16 has LSB ~1.5e-5, so tolerance 1e-3 is safe
            rel_err = abs(result_float - expected_float) / (expected_float + 1e-9)
            abs_err = abs(result_float - expected_float)
            
            if rel_err > 1e-3 and abs_err > 0.01:
                raise TestFailure(f"Area mismatch: got {result_float:.6f}, expected {expected_float:.6f} (rel_err={rel_err:.6f})")
                
            passed += 1
            cocotb.log.info(f"  Result: {result_float:.6f}, Expected: {expected_float:.6f} [PASS]")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")