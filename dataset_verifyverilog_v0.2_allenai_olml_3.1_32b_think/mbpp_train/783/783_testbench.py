import cocotb
from cocotb.triggers import Timer
import math

def float_to_fixed(f):
    """Convert float to Q16.16 fixed point integer."""
    return int(f * 65536)

def fixed_to_float(fixed):
    """Convert Q16.16 fixed point integer to float."""
    return fixed / 65536.0

@cocotb.test()
async def test_rgb_to_hsv(dut):
    """Test RGB to HSV conversion."""
    
    # Test cases: (r, g, b) -> (h, s, v)
    test_cases = [
        (255, 255, 255, 0.0, 0.0, 100.0),
        (0, 215, 0, 120.0, 100.0, 84.31372549019608),
        (10, 215, 110, 149.26829268292684, 95.34883720930233, 84.31372549019608),
        (0, 0, 0, 0.0, 0.0, 0.0),
        (255, 0, 0, 0.0, 100.0, 100.0)
    ]

    passed = 0
    total = len(test_cases)

    for r_in, g_in, b_in, h_exp, s_exp, v_exp in test_cases:
        # Normalize inputs to 0-1 range and convert to Q16.16
        # Input is typically 0-255. The spec says normalized 0.0-1.0.
        # So we divide by 255.0 then convert to fixed point.
        r_fixed = float_to_fixed(r_in / 255.0)
        g_fixed = float_to_fixed(g_in / 255.0)
        b_fixed = float_to_fixed(b_in / 255.0)
        
        dut.r.value = r_fixed
        dut.g.value = g_fixed
        dut.b.value = b_fixed
        
        # Wait a small amount for combinational logic
        await Timer(10, units='ns')
        
        # Read outputs
        h_out = dut.h.value.signed_integer if dut.h.value.is_signed else int(dut.h.value)
        s_out = dut.s.value.signed_integer if dut.s.value.is_signed else int(dut.s.value)
        v_out = dut.v.value.signed_integer if dut.v.value.is_signed else int(dut.v.value)
        
        h_float = fixed_to_float(h_out)
        s_float = fixed_to_float(s_out)
        v_float = fixed_to_float(v_out)
        
        # Allow small tolerance for fixed-point arithmetic errors (e.g., +/- 0.1)
        h_err = abs(h_float - h_exp)
        s_err = abs(s_float - s_exp)
        v_err = abs(v_float - v_exp)
        
        tol = 0.2
        
        if h_err < tol and s_err < tol and v_err < tol:
            passed += 1
            print(f"PASS: RGB({r_in},{g_in},{b_in}) -> H={h_float:.2f} S={s_float:.2f} V={v_float:.2f}")
        else:
            print(f"FAIL: RGB({r_in},{g_in},{b_in}) -> Got H={h_float:.2f} S={s_float:.2f} V={v_float:.2f}, "
                  f"Exp H={h_exp:.2f} S={s_exp:.2f} V={v_exp:.2f}")

    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total