import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import math

# Helper to convert float to Q16.16
def to_q16_16(val):
    return int(val * 65536) & 0xFFFFFFFF

# Helper to convert Q16.16 to float
def from_q16_16(val):
    if val & 0x80000000:  # Sign bit set
        val = val - 0x100000000
    return val / 65536.0

@cocotb.test()
async def test_rect_intersection_area(dut):
    """Test intersection area calculation for various cases"""
    
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.w.value = 0
    dut.h.value = 0
    dut.alpha_deg.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (1, 1, 45),      # Example 1
        (6, 4, 30),      # Example 2
        (100, 100, 0),   # Edge: Zero angle
        (100, 100, 90),  # Edge: 90 degrees
        (2, 100, 90),    # Edge: Thin rectangle
    ]
    
    passed = 0
    total = len(test_cases)
    
    for w, h, alpha in test_cases:
        # Expected calculation (Python reference)
        w_f, h_f = float(w), float(h)
        alpha_f = float(alpha)
        
        if alpha_f > 90:
            alpha_f = 180 - alpha_f
        
        if alpha_f == 0:
            expected = w_f * h_f
        elif alpha_f == 90:
            expected = min(w_f, h_f) ** 2
        else:
            # Ensure w >= h
            if h_f > w_f:
                w_f, h_f = h_f, w_f
            
            a_rad = math.radians(alpha_f)
            t = math.tan(a_rad / 2)
            
            if t > h_f / w_f:
                expected = h_f * h_f / math.sin(a_rad)
            else:
                expected = w_f * h_f - ((w_f - h_f * t)**2 + (h_f - w_f * t)**2) * math.tan(a_rad) / 4
        
        # Convert inputs to Q16.16
        dut.w.value = to_q16_16(w)
        dut.h.value = to_q16_16(h)
        dut.alpha_deg.value = to_q16_16(alpha)
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 1024 cycles + buffer)
        max_cycles = 1100
        for _ in range(max_cycles):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Read result
        result_q16 = int(dut.area.value)
        result_float = from_q16_16(result_q16)
        
        # Verify with tolerance (0.1% relative error allowed for fixed-point approx)
        error = abs(result_float - expected) / max(expected, 1e-9)
        
        if error < 0.001:
            passed += 1
            dut._log.info(f"PASS: w={w}, h={h}, alpha={alpha} -> Result: {result_float:.6f}, Expected: {expected:.6f}")
        else:
            dut._log.error(f"FAIL: w={w}, h={h}, alpha={alpha} -> Result: {result_float:.6f}, Expected: {expected:.6f}, Error: {error:.4f}")
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
