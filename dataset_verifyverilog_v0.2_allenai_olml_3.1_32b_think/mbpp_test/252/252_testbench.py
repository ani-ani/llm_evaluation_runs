import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import math

# Helper to convert float to Q16.16 format
def float_to_q16_16(f):
    return int(f * 65536) & 0xFFFFFFFF

# Helper to convert Q16.16 to float
def q16_16_to_float(q):
    if q & 0x80000000:  # negative
        return (q - 0x100000000) / 65536.0
    return q / 65536.0

@cocotb.test()
async def test_complex_to_polar(dut):
    """Test complex to polar conversion"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.real_in.value = 0
    dut.imag_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (real, imag, expected_mag, expected_angle)
        (1.0, 0.0, 1.0, 0.0),
        (4.0, 0.0, 4.0, 0.0),
        (5.0, 0.0, 5.0, 0.0),
        (3.0, 4.0, 5.0, math.atan2(4.0, 3.0)),  # Additional test
        (0.0, 5.0, 5.0, math.pi/2),  # Imaginary axis
        (-3.0, 4.0, 5.0, math.atan2(4.0, -3.0)),  # Quadrant II
    ]
    
    passed = 0
    total = len(test_cases)
    
    for real, imag, exp_mag, exp_angle in test_cases:
        # Convert to Q16.16
        real_q = float_to_q16_16(real)
        imag_q = float_to_q16_16(imag)
        
        dut.real_in.value = real_q
        dut.imag_in.value = imag_q
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 50 cycles to be safe)
        timeout = 50
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            print(f"Test failed: timeout for input ({real}, {imag})")
            continue
        
        # Read results
        mag_q = int(dut.magnitude.value)
        angle_q = int(dut.angle.value)
        
        mag = q16_16_to_float(mag_q)
        angle = q16_16_to_float(angle_q)
        
        # Allow small tolerance for fixed-point errors
        mag_error = abs(mag - exp_mag)
        angle_error = abs(angle - exp_angle)
        
        # Handle angle wrapping for atan2 result
        if angle_error > 0.1:  # Check alternative angle representation
            if exp_angle < 0:
                alt_exp = exp_angle + 2*math.pi
            else:
                alt_exp = exp_angle - 2*math.pi
            angle_error = min(angle_error, abs(angle - alt_exp))
        
        if mag_error < 0.02 and angle_error < 0.02:
            passed += 1
            print(f"✓ Input ({real}, {imag}): mag={mag:.4f} (exp {exp_mag:.4f}), angle={angle:.4f} rad (exp {exp_angle:.4f})")
        else:
            print(f"✗ Input ({real}, {imag}): mag={mag:.4f} (exp {exp_mag:.4f}), angle={angle:.4f} rad (exp {exp_angle:.4f})")
            print(f"  Raw: mag_q=0x{mag_q:08X}, angle_q=0x{angle_q:08X}")
    
    print(f"
Result: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} of {total} tests passed"
