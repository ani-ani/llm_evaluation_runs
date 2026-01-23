import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
import random

# Helper to convert float to Q16.16
def float_to_q16_16(f):
    return int(f * 65536)

# Helper to convert Q16.16 to float
def q16_16_to_float(q):
    return q / 65536.0

@cocotb.test()
async def test_rocket_fuel_basic(dut):
    """Test basic functionality with small inputs"""
    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.payload.value = 0
    dut.num_planets.value = 0
    for i in range(8):
        dut.a[i].value = 0
        dut.b[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Example 1
    # Input: n=2, m=12, a=[11,8], b=[7,5]
    # Expected Output: 10.0
    
    payload = float_to_q16_16(12.0)
    a_vals = [float_to_q16_16(11.0), float_to_q16_16(8.0)]
    b_vals = [float_to_q16_16(7.0), float_to_q16_16(5.0)]

    dut.payload.value = payload
    dut.num_planets.value = 2
    for i in range(2):
        dut.a[i].value = a_vals[i]
        dut.b[i].value = b_vals[i]

    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    timeout = 1000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Did not finish in time")
    
    if dut.error.value == 1:
        raise TestFailure("Error flag raised unexpectedly")

    result = dut.result.value
    result_float = q16_16_to_float(result)
    
    # Allow some tolerance for floating point error in simulation steps
    if abs(result_float - 10.0) > 0.1:
        raise TestFailure(f"Expected 10.0, got {result_float}")
    
    dut._log.info(f"Test 1 Passed: Result = {result_float}")

@cocotb.test()
async def test_rocket_fuel_impossible(dut):
    """Test case where coefficients are 1"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: Example 2 (or similar with 1)
    # n=3, m=1, a=[1,4,1], b=[2,5,3]
    # Coefficient 1 makes it impossible
    
    payload = float_to_q16_16(1.0)
    a_vals = [float_to_q16_16(1.0), float_to_q16_16(4.0), float_to_q16_16(1.0)]
    b_vals = [float_to_q16_16(2.0), float_to_q16_16(5.0), float_to_q16_16(3.0)]

    dut.payload.value = payload
    dut.num_planets.value = 3
    for i in range(3):
        dut.a[i].value = a_vals[i]
        dut.b[i].value = b_vals[i]

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for error or done
    timeout = 1000
    found_error = False
    for _ in range(timeout):
        if dut.error.value == 1:
            found_error = True
            break
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if not found_error:
        raise TestFailure("Expected error flag for coefficient 1")
    
    dut._log.info("Test 2 Passed: Detected impossible case")

@cocotb.test()
async def test_rocket_fuel_larger(dut):
    """Test with larger payload and coefficients"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Input: n=6, m=2, a=[4,6,3,3,5,6], b=[2,6,3,6,5,3]
    # Expected: ~85.48
    
    payload = float_to_q16_16(2.0)
    a_vals = [float_to_q16_16(x) for x in [4,6,3,3,5,6]]
    b_vals = [float_to_q16_16(x) for x in [2,6,3,6,5,3]]

    dut.payload.value = payload
    dut.num_planets.value = 6
    for i in range(6):
        dut.a[i].value = a_vals[i]
        dut.b[i].value = b_vals[i]

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    timeout = 2000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Did not finish in time")
    
    if dut.error.value == 1:
        raise TestFailure("Error flag raised unexpectedly")

    result = dut.result.value
    result_float = q16_16_to_float(result)
    
    # Expected ~85.48
    if abs(result_float - 85.48) > 1.0:
        raise TestFailure(f"Expected ~85.48, got {result_float}")
    
    dut._log.info(f"Test 3 Passed: Result = {result_float}")
