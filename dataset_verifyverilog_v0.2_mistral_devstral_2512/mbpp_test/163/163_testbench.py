import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper function to convert float to Q16.16 format
def to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# Helper function to convert Q16.16 to float
def from_q16_16(value):
    if value & 0x80000000:  # Negative
        return (value - 0x100000000) / 65536.0
    else:
        return value / 65536.0

@cocotb.test()
async def test_polygon_area(dut):
    """Test polygon area calculation with Q16.16 fixed-point arithmetic"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.s.value = 0
    dut.l.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (s, l_float, expected_area_float)
    test_cases = [
        (4, 20.0, 400.0),
        (10, 15.0, 1731.197),
        (9, 7.0, 302.909)
    ]
    
    for s, l_float, expected in test_cases:
        dut._log.info(f"Test: s={s}, l={l_float}, expected={expected}")
        
        # Convert inputs to Q16.16
        l_fixed = to_q16_16(l_float)
        
        # Start computation
        dut.s.value = s
        dut.l.value = l_fixed
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 100 cycles)
        timeout = 100
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Timeout after {timeout} cycles")
        
        # Get result
        result_fixed = dut.result.value.integer
        result_float = from_q16_16(result_fixed)
        
        # Check with relative tolerance
        if not math.isclose(result_float, expected, rel_tol=0.01):
            raise TestFailure(f"Mismatch: got {result_float:.4f}, expected {expected:.4f}, diff={abs(result_float - expected):.4f}")
        
        dut._log.info(f"Result: {result_float:.4f} (Q16.16: 0x{result_fixed:08X})")
        
        # Wait for done to go low before next test
        await FallingEdge(dut.done)
        await RisingEdge(dut.clk)
    
    dut._log.info("All 3/3 tests passed!")
