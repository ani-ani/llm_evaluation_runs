import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_rgb_to_hsv(dut):
    # Generate 100MHz clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Hyperparameters
    DIVIDER = 255
    SCALE = 1000  # Scaling factor
    
    # Test cases (original values converted to scaled integers)
    test_cases = [
        # r, g, b,  exp_h, exp_s, exp_v
        (255, 255, 255, 0,     0, 10000),  # White
        (0,   215, 0,   12000, 10000, round(215*100000/DIVIDER/1000)),
        (10,  215, 110, 14927, 9534, round(215*100000/DIVIDER/1000))
    ]
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    
    passed = 0
    total = len(test_cases)
    
    for tc in test_cases:
        r, g, b, exp_h, exp_s, exp_v = tc
        
        # Apply inputs
        dut.r.value = r
        dut.g.value = g
        dut.b.value = b
        dut.start.value = 1
        
        # Wait 1 cycle for start capture
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            dut._log.error("Timeout waiting for done signal")
            continue
        
        # Check outputs with 1% tolerance
        h_val = dut.h.value.integer
        s_val = dut.s.value.integer
        v_val = dut.v.value.integer
        
        h_ok = abs(h_val - exp_h) <= 100  # Allow ±1 degree
        s_ok = abs(s_val - exp_s) <= 200  # Allow ±2%
        v_ok = abs(v_val - exp_v) <= 200  # Allow ±2%
        
        if h_ok and s_ok and v_ok:
            passed += 1
            dut._log.info(f"PASS: RGB({r},{g},{b}) => HSV({h_val},{s_val},{v_val})")
        else:
            msg = f"FAIL: RGB({r},{g},{b}) => HSV({h_val},{s_val},{v_val})"
            msg += f" expected ({exp_h},{exp_s},{exp_v})"
            if not h_ok: msg += f" | H error: {abs(h_val-exp_h)}"
            if not s_ok: msg += f" | S error: {abs(s_val-exp_s)}"
            if not v_ok: msg += f" | V error: {abs(v_val-exp_v)}"
            dut._log.error(msg)
    
    dut._log.info(f"Test Summary: {passed}/{total} passed")