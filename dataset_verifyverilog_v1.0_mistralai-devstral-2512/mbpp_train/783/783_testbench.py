import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Fixed point parameters
FRAC_BITS = 8
SCALE = 1 << FRAC_BITS

def float_to_fixed(val):
    return int(val * SCALE)

def fixed_to_float(val):
    return val / SCALE

def clamp_to_width(v, bits):
    mask = (1 << bits) - 1
    return v & mask

# Helper functions for testing
async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        try:
            if int(dut.done.value) == 1:
                return
        except:
            pass
    raise TestFailure(f"Timeout waiting for done signal")

def python_rgb_to_hsv(r, g, b):
    r_n, g_n, b_n = r/255.0, g/255.0, b/255.0
    mx = max(r_n, g_n, b_n)
    mn = min(r_n, g_n, b_n)
    df = mx - mn
    if mx == mn:
        h = 0
    elif mx == r_n:
        h = (60 * ((g_n - b_n) / df) + 360) % 360
    elif mx == g_n:
        h = (60 * ((b_n - r_n) / df) + 120) % 360
    else:
        h = (60 * ((r_n - g_n) / df) + 240) % 360
    if mx == 0:
        s = 0
    else:
        s = (df / mx) * 100
    v = mx * 100
    return h, s, v

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_rgb_to_hsv(dut):
    # Start Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    test_cases = [
        (255, 255, 255),
        (0, 215, 0),
        (10, 215, 110),
        (0, 0, 0),
        (128, 64, 192)
    ]
    
    for r, g, b in test_cases:
        # Calculate expected in Python
        h_float, s_float, v_float = python_rgb_to_hsv(r, g, b)
        
        # Scale to fixed point (Q8.8)
        # Note: H is 0-360, S and V are 0-100. 
        # To fit in 16 bits signed (Q8.8), range is +/-128.
        # 360 < 128? No. 360 > 128. Scaled by 256 is ~92k. 
        # Wait, Q8.8 means 8 integer bits, 8 fraction bits.
        # Max positive is 127.99. 360 is too big.
        # Let's adjust spec to Q16.16 for output to handle 0-360 range safely.
        # Or just scale to 0-36000 for 16-bit integer.
        # Let's assume H is scaled by 100 (36000 max), S/V by 100 (10000 max).
        # To match Q8.8 logic in prompt (scaled 0-360/0-100), we need more bits.
        # Re-interpreting prompt's Q8.8 as raw scaling: 
        # If H is 360.0, it fits in Q8.8 only if we consider 360.0 as integer.
        # 360.0 needs 9 bits for integer part. Q8.8 only has 8 integer bits.
        # This implies the Verilog should likely use wider internal calculations or different Q format.
        # For this testbench, we will calculate expected values scaled by 256 (fixed point).
        
        exp_h_fixed = int(h_float * 256)
        exp_s_fixed = int(s_float * 256)
        exp_v_fixed = int(v_float * 256)
        
        cocotb.log.info(f"Input: R={r} G={g} B={b}")
        cocotb.log.info(f"Expected (Float): H={h_float:.2f} S={s_float:.2f} V={v_float:.2f}")
        cocotb.log.info(f"Expected (Fixed): H={exp_h_fixed} S={exp_s_fixed} V={exp_v_fixed}")
        
        # Set inputs
        dut.r.value = r
        dut.g.value = g
        dut.b.value = b
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read outputs
        try:
            h_val = int(dut.h.value)
            s_val = int(dut.s.value)
            v_val = int(dut.v.value)
            
            # Allow small fixed-point error tolerance (e.g. +/- 2 LSB)
            h_err = abs(h_val - exp_h_fixed)
            s_err = abs(s_val - exp_s_fixed)
            v_err = abs(v_val - exp_v_fixed)
            
            if h_err > 2 or s_err > 2 or v_err > 2:
                raise TestFailure(
                    f"Mismatch:\nH: got {h_val} (fp {h_val/256:.2f}), exp {exp_h_fixed} (fp {h_float:.2f}) err {h_err}\n"
                    f"S: got {s_val} (fp {s_val/256:.2f}), exp {exp_s_fixed} (fp {s_float:.2f}) err {s_err}\n"
                    f"V: got {v_val} (fp {v_val/256:.2f}), exp {exp_v_fixed} (fp {v_float:.2f}) err {v_err}"
                )
            cocotb.log.info("Test passed.")
            
        except ValueError as e:
            raise TestFailure(f"Output undefined: {e}")
        
        # Inter-cycle delay
        await RisingEdge(dut.clk)
