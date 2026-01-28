import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Configuration
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 500

# Fixed-point conversion (Q16.16)
FRAC_BITS = 16
SCALE = 1 << FRAC_BITS

def float_to_fixed(f):
    return int(f * SCALE)

def fixed_to_float(fixed):
    return fixed / SCALE

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
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

async def start_computation(dut, r, g, b):
    dut.r_in.value = r
    dut.g_in.value = g
    dut.b_in.value = b
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# Python reference implementation
def rgb_to_hsv_ref(r, g, b):
    r_float, g_float, b_float = r/255.0, g/255.0, b/255.0
    mx = max(r_float, g_float, b_float)
    mn = min(r_float, g_float, b_float)
    df = mx - mn
    if mx == mn:
        h = 0
    elif mx == r_float:
        h = (60 * ((g_float - b_float) / df) + 360) % 360
    elif mx == g_float:
        h = (60 * ((b_float - r_float) / df) + 120) % 360
    elif mx == b_float:
        h = (60 * ((r_float - g_float) / df) + 240) % 360
    if mx == 0:
        s = 0
    else:
        s = (df / mx) * 100
    v = mx * 100
    return h, s, v

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_rgb_to_hsv(dut):
    """Test RGB to HSV conversion with test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        (255, 255, 255, 0, 0.0, 100.0),
        (0, 215, 0, 120.0, 100.0, 84.31372549019608),
        (10, 215, 110, 149.26829268292684, 95.34883720930233, 84.31372549019608),
    ]
    
    for i, (r, g, b, exp_h, exp_s, exp_v) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: RGB({r},{g},{b})")
        
        # Get reference
        ref_h, ref_s, ref_v = rgb_to_hsv_ref(r, g, b)
        
        # Start computation
        await start_computation(dut, r, g, b)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read results
        h_raw = int(dut.h_out.value)
        s_raw = int(dut.s_out.value)
        v_raw = int(dut.v_out.value)
        
        h_result = fixed_to_float(h_raw)
        s_result = fixed_to_float(s_raw)
        v_result = fixed_to_float(v_raw)
        
        # Allow tolerance for fixed-point errors
        tolerance = 0.5  # 0.5 degree/unit tolerance
        
        dut._log.info(f"  Result: H={h_result:.2f}, S={s_result:.2f}, V={v_result:.2f}")
        dut._log.info(f"  Expected: H={exp_h:.2f}, S={exp_s:.2f}, V={exp_v:.2f}")
        
        if not (abs(h_result - exp_h) < tolerance and 
                abs(s_result - exp_s) < tolerance and 
                abs(v_result - exp_v) < tolerance):
            raise TestFailure(f"Test {i+1} failed: Expected ({exp_h}, {exp_s}, {exp_v}), got ({h_result}, {s_result}, {v_result})")
        
        dut._log.info(f"  PASS")
        
        # Wait a cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")
