import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import math

# Helper to convert float to Q16.16
def to_q16_16(val):
    return int(val * 65536)

# Helper to convert Q32.32 result to float
def to_float_q32_32(val):
    return val / (2**32)

@cocotb.test()
async def test_bus_excursion(dut):
    """Test the bus excursion module with adapted inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.l.value = 0
    dut.v1.value = 0
    dut.v2.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Input "3 6 1 2 1" -> Expected ~4.7142857143
    # n = 3, l = 6, v1 = 1, v2 = 2
    dut.n.value = 3
    dut.l.value = to_q16_16(6.0)
    dut.v1.value = to_q16_16(1.0)
    dut.v2.value = to_q16_16(2.0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (32 iterations + overhead)
    cycles = 0
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        cycles += 1
        if cycles > 100:
            raise TestFailure("Timeout: Module did not finish in 100 cycles")
            
    result_val = dut.result.value
    time_val = to_float_q32_32(int(result_val))
    expected = 4.7142857143
    
    print(f"Test 1: Result={time_val:.10f}, Expected={expected:.10f}")
    
    # Check relative error < 1e-5 (fixed point limits precision slightly vs float)
    if abs(time_val - expected) / expected > 1e-5:
        raise TestFailure(f"Result mismatch. Got {time_val}, expected {expected}")

    # Test Case 2: Input "5 10 1 2 5" -> Expected 5.0
    # n = 1, l = 10, v1 = 1, v2 = 2
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 1
    dut.l.value = to_q16_16(10.0)
    dut.v1.value = to_q16_16(1.0)
    dut.v2.value = to_q16_16(2.0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        cycles += 1
        if cycles > 100:
            raise TestFailure("Timeout: Module did not finish in 100 cycles")
            
    result_val = dut.result.value
    time_val = to_float_q32_32(int(result_val))
    expected = 5.0
    
    print(f"Test 2: Result={time_val:.10f}, Expected={expected:.10f}")
    
    if abs(time_val - expected) > 1e-4:
        raise TestFailure(f"Result mismatch. Got {time_val}, expected {expected}")

    print("All tests passed!")
