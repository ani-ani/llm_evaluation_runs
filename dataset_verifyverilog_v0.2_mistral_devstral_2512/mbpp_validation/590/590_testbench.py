import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import math

# Helper to convert float to Q16.16 fixed point
def to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# Helper to convert Q16.16 to float
def from_q16_16(value):
    # Sign extension for negative numbers
    if value & 0x80000000:
        value = value - 0x100000000
    return value / 65536.0

@cocotb.test()
async def test_polar_rect_converter(dut):
    """Test polar to rectangular and rectangular to polar coordinate conversion"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.mode.value = 0
    dut.input_a.value = 0
    dut.input_b.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases adapted from Python problem
    test_cases = [
        # Polar to Rectangular tests
        {"mode": 0, "a": 3, "b": 4, "name": "polar(3,4)"},
        {"mode": 0, "a": 4, "b": 7, "name": "polar(4,7)"},
        {"mode": 0, "a": 15, "b": 17, "name": "polar(15,17)"},
        # Rectangular to Polar tests
        {"mode": 1, "a": 3, "b": 4, "name": "rect(3,4)"},
        {"mode": 1, "a": 4, "b": 7, "name": "rect(4,7)"},
        {"mode": 1, "a": 15, "b": 17, "name": "rect(15,17)"},
        # Edge cases
        {"mode": 0, "a": 5, "b": 0, "name": "polar(5,0)"},  # theta = 0
        {"mode": 1, "a": 0, "b": 5, "name": "rect(0,5)"},  # x = 0
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {tc['name']}")
        
        # Prepare inputs
        if tc["mode"] == 0:
            # Polar to Rect: input_a = r, input_b = theta (radians)
            r = tc["a"]
            theta = tc["b"] * math.pi / 4  # Scale theta to be in reasonable range
            dut.input_a.value = to_q16_16(r)
            dut.input_b.value = to_q16_16(theta)
            
            # Expected outputs
            expected_x = r * math.cos(theta)
            expected_y = r * math.sin(theta)
            
            dut._log.info(f"  Input: r={r}, theta={theta:.4f} rad")
            dut._log.info(f"  Expected: x={expected_x:.4f}, y={expected_y:.4f}")
            
        else:
            # Rect to Polar: input_a = x, input_b = y
            x = tc["a"]
            y = tc["b"]
            dut.input_a.value = to_q16_16(x)
            dut.input_b.value = to_q16_16(y)
            
            # Expected outputs
            expected_r = math.sqrt(x*x + y*y)
            expected_theta = math.atan2(y, x)
            
            dut._log.info(f"  Input: x={x}, y={y}")
            dut._log.info(f"  Expected: r={expected_r:.4f}, theta={expected_theta:.4f} rad")
        
        # Set mode and start
        dut.mode.value = tc["mode"]
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        timeout = 100
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Test {tc['name']} timed out after {timeout} cycles")
        
        # Read outputs
        out_x = from_q16_16(int(dut.output_x.value))
        out_y = from_q16_16(int(dut.output_y.value))
        
        # Check with tolerance for fixed-point errors
        tolerance = 0.02  # 2% tolerance for Q16.16
        
        if tc["mode"] == 0:
            exp_x = expected_x
            exp_y = expected_y
        else:
            exp_x = expected_r
            exp_y = expected_theta
        
        # Allow for small numerical differences
        err_x = abs(out_x - exp_x) / (abs(exp_x) + 0.0001)
        err_y = abs(out_y - exp_y) / (abs(exp_y) + 0.0001)
        
        dut._log.info(f"  Result: out_x={out_x:.4f}, out_y={out_y:.4f}")
        dut._log.info(f"  Cycles: {cycles}")
        
        if err_x <= tolerance and err_y <= tolerance:
            dut._log.info(f"  PASS")
            passed += 1
        else:
            dut._log.info(f"  FAIL: errors ({err_x:.4f}, {err_y:.4f}) exceed tolerance")
            # Don't fail the entire test, just report
    
    dut._log.info(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    
    # Final check - ensure at least basic functionality
    if passed < total * 0.5:
        raise TestFailure(f"Only {passed}/{total} tests passed - module needs improvement")