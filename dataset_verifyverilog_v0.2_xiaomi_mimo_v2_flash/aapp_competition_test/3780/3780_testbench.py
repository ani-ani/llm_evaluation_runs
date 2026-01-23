import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import math

# Helper to convert float to scaled fixed point (Q16.16 / 16)
def to_fixed_scaled(val):
    scaled = val * (2**16) / 16.0
    return int(round(scaled))

# Helper to convert scaled fixed point back to float
def from_fixed_scaled(val):
    return val * 16.0 / (2**16)

@cocotb.test()
async def test_rescue_planner(dut):
    """Test the rescue planner module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.dx.value = 0
    dut.dy.value = 0
    dut.v_max.value = 0
    dut.t_wind.value = 0
    dut.vx.value = 0
    dut.vy.value = 0
    dut.wx.value = 0
    dut.wy.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (dx, dy, v_max, t_wind, vx, vy, wx, wy, expected_time)
    test_cases = [
        (0, 0, 5, 2, -1, -1, -1, 0, 3.729935587093555327),
        (0, 1000, 100, 1000, -50, 0, 50, 0, 11.547005383792516398),
        (0, 1000, 100, 5, 0, -50, 0, 50, 10.0),
        (0, -1000, 0, 10, 0, 50, 0, 50, 10.0),
        (0, 0, 1, 1, 0, 0, 0, 0, 0.0),
        (5, 5, 3, 2, -1, -1, -1, 0, 3.729935587093555327),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (dx_in, dy_in, vmax_in, tw_in, vx_in, vy_in, wx_in, wy_in, expected) in enumerate(test_cases):
        
        # Scale inputs (divide by 16, multiply by 2^16)
        dut.dx.value = to_fixed_scaled(dx_in)
        dut.dy.value = to_fixed_scaled(dy_in)
        dut.v_max.value = to_fixed_scaled(vmax_in)
        dut.t_wind.value = to_fixed_scaled(tw_in)
        dut.vx.value = to_fixed_scaled(vx_in)
        dut.vy.value = to_fixed_scaled(vy_in)
        dut.wx.value = to_fixed_scaled(wx_in)
        dut.wy.value = to_fixed_scaled(wy_in)
        
        # Start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 10000
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done")
            
        # Read result
        result_scaled = int(dut.result.value)
        result_time = from_fixed_scaled(result_scaled)
        
        # Check result (relative error tolerance 1e-5 is sufficient for this problem)
        if expected == 0.0:
            if abs(result_time) > 1e-4:
                print(f"Test {i+1} FAILED: Expected {expected}, Got {result_time}")
            else:
                passed += 1
        else:
            rel_err = abs(result_time - expected) / expected
            if rel_err < 1e-5:
                passed += 1
            else:
                print(f"Test {i+1} FAILED: Expected {expected}, Got {result_time}, Rel Err {rel_err}")
        
        await Timer(200, units='ns')
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed} tests passed")
