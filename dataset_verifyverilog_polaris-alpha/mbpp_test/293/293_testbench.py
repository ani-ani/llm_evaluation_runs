import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_right_angle(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases scaled to Q8.8 format
    test_cases = [
        (7,  8,  10.63014581273465),
        (3,  4,  5.0),
        (7, 15, 16.55294535724685),
        (0,  0,  0.0)   # Edge case
    ]
    
    passed = 0
    total = len(test_cases)
    
    # Convert expected to Q8.8 format
    def fp8_8(val):
        return int(val * 256)
    
    for w, h, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Apply inputs
        dut.w.value = w
        dut.h.value = h
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation (16 cycles + 1 for output)
        await ClockCycles(dut.clk, 17)
        
        # Check result
        dut._log.info(f"Input: {w},{h} => Got: {dut.result.value.integer/256:.6f}, Expected: {expected}")
        expected_fp = fp8_8(expected)
        if dut.result.value == expected_fp:
            passed += 1
            dut._log.info(f"PASS: {w},{h} = {expected}")
        else:
            actual = dut.result.value.integer/256
            dut._log.error(f"FAIL: {w},{h} = {actual:.6f}, expected {expected}")
        
    dut._log.info(f"{passed}/{total} tests passed")