import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

# Q16.16 conversion helpers
def float_to_q16(f):
    return int(f * (1 << 16)) & 0xFFFFFFFF

def q16_to_float(q):
    return q / 65536.0 if q < 0x80000000 else (q - 0x100000000) / 65536.0

@cocotb.test()
async def test_polar_rect(dut):
    # Generate clock (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (original values converted to Q16.16)
    test_cases = [
        # Test 1: (r=5.0, θ=0.927 rad) → (x≈3.0, y≈4.0)
        {"r": 5.0, "theta": 0.927, "exp_x": 3.0, "exp_y": 4.0},
        # Test 2: (r=8.06, θ=1.051 rad) → (x≈4.0, y≈7.0)
        {"r": 8.062, "theta": 1.051, "exp_x": 4.0, "exp_y": 7.0},
        # Test 3: (r=15.0, θ=0.0) → (x=15.0, y=0.0)
        {"r": 15.0, "theta": 0.0, "exp_x": 15.0, "exp_y": 0.0},
    ]
    
    passed = 0
    tolerance = 0.01  # 1% tolerance for fixed-point error
    
    for case in test_cases:
        # Convert to Q16.16
        r_q16 = float_to_q16(case["r"])
        theta_q16 = float_to_q16(case["theta"])
        exp_x = float_to_q16(case["exp_x"])
        exp_y = float_to_q16(case["exp_y"])
        
        # Apply inputs
        dut.r_q16.value = r_q16
        dut.theta_q16.value = theta_q16
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 3 cycles for result
        for _ in range(3):
            await RisingEdge(dut.clk)
        
        # Check outputs
        x_val = dut.x_q16.value.integer
        y_val = dut.y_q16.value.integer
        
        # Convert to float for error calculation (optional)
        x_float = q16_to_float(x_val)
        y_float = q16_to_float(y_val)
        exp_x_float = case["exp_x"]
        exp_y_float = case["exp_y"]
        
        # Check with tolerance
        x_error = abs(x_float - exp_x_float) / (exp_x_float if exp_x_float != 0 else 1)
        y_error = abs(y_float - exp_y_float) / (exp_y_float if exp_y_float != 0 else 1)
        
        if (x_error <= tolerance and y_error <= tolerance):
            passed += 1
            dut._log.info(f"PASS: r={case['r']} θ={case['theta']} → x={x_float:.4f}, y={y_float:.4f}")
        else:
            dut._log.error(f"FAIL: r={case['r']} θ={case['theta']}")
            dut._log.error(f"  Expected x={exp_x_float:.4f} y={exp_y_float:.4f}")
            dut._log.error(f"  Received x={x_float:.4f} (err={x_error*100:.2f}%) y={y_float:.4f} (err={y_error*100:.2f}%)")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")