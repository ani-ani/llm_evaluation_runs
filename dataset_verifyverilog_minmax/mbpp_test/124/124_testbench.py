import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
from math import atan2
import numpy as np

@cocotb.test()
async def test_complex_angle(dut):
    # Create clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Convert float to Q16.16 (integer)
    def fp(x):
        return int(x * (1<<16)) & 0xFFFFFFFF
    
    # Test cases: (real, imag, expected_radians)
    cases = [
        (0.0, 1.0, np.pi/2),       # Pure imaginary (j)
        (2.0, 1.0, atan2(1,2)),    # 2 + j 
        (0.0, 2.0, np.pi/2),       # 2j
        (1.0, 0.0, 0.0),           # Positive real
        (-1.0, 0.0, np.pi)         # Negative real
    ]
    
    # Initialize
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for i, (re, im, exp) in enumerate(cases):
        dut.real_part.value = fp(re)
        dut.imag_part.value = fp(im)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await FallingEdge(dut.done)  # Wait for done LOW
        await RisingEdge(dut.done)   # Wait for done HIGH
        
        # Check result with 0.001 tolerance (1/1000 of full scale)
        actual = dut.angle.value.signed_integer / (1<<16)
        tolerance = 0.001
        diff = abs(actual - exp)
        
        if diff < tolerance or (abs(2*np.pi + actual - exp) < tolerance):
            passed += 1
            dut._log.info(f"Test {i}: PASS (Real={re}, Imag={im}) Actual: {actual:.6f}, Expected: {exp:.6f}")
        else:
            dut._log.error(f"Test {i}: FAIL (Real={re}, Imag={im}) Actual: {actual:.6f}, Expected: {exp:.6f}, Diff: {diff:.6f}")
        await RisingEdge(dut.clk)
        
    dut._log.info(f"{passed}/{len(cases)} tests passed")