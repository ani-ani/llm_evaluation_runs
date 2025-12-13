import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

# Q16.16 conversion helpers
def float_to_q16_16(val):
    return int(val * (1 << 16)) & 0xFFFFFFFF

def q16_16_to_float(val):
    return val / 65536.0 if val < 0x80000000 else (val - 0x100000000) / 65536.0

@cocotb.test()
async def test_polynomial_root(dut):
    # Create 100MHz clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await Timer(20, units="ns")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Test case 1: 1 + 2x = 0 → x = -0.5
        {"coeffs": [float_to_q16_16(1), float_to_q16_16(2), 0,0,0,0,0,0], 
         "degree": 1,
         "expected": float_to_q16_16(-0.5)},
        
        # Test case 2: (x-1)(x-2)(x-3) = -6 + 11x -6x^2 + x^3 → root at 1.0
        {"coeffs": [float_to_q16_16(-6), float_to_q16_16(11), float_to_q16_16(-6), float_to_q16_16(1), 0,0,0,0], 
         "degree": 3,
         "expected": float_to_q16_16(1.0)},
        
        # Test case 3: Edge case - x^2 - 4 = 0 → root at 2.0
        {"coeffs": [float_to_q16_16(-4), float_to_q16_16(0), float_to_q16_16(1), 0,0,0,0,0], 
         "degree": 2,
         "expected": float_to_q16_16(2.0)}
    ]
    
    passed = 0
    tolerance = 0x400  # ~0.015625 error tolerance in Q16.16
    
    for case in test_cases:
        # Load coefficients
        for i in range(8):
            dut.coeffs[i].value = case["coeffs"][i]
        dut.degree.value = case["degree"]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        result = dut.x_out.value.signed_integer
        expected = case["expected"]
        
        # Verify |result - expected| < tolerance
        if abs(result - expected) < tolerance:
            passed += 1
            dut._log.info(f"PASS: Got {q16_16_to_float(result)} ≈ expected {q16_16_to_float(expected)}")
        else:
            dut._log.error(f"FAIL: Got {q16_16_to_float(result)} ({hex(result)}), expected {q16_16_to_float(expected)} ({hex(expected)}), diff {abs(result - expected)}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")