import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import math

def float_to_q16_16(value):
    """Convert float to Q16.16 fixed-point representation"""
    return int(value * 65536) & 0xFFFFFFFF

def q16_16_to_float(value):
    """Convert Q16.16 fixed-point to float"""
    if value & 0x80000000:  # Negative number
        return (value - 0x100000000) / 65536.0
    else:
        return value / 65536.0

@cocotb.test()
async def test_laser_tag_wall(dut):
    """Test laser tag wall hit calculation"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.x1.value = 0
    dut.y1.value = 0
    dut.x2.value = 0
    dut.y2.value = 0
    dut.x3.value = 0
    dut.y3.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Mirror (5,10)-(10,10), Shooter (10,0)
    # Expected: wall hit at y=0
    dut.x1.value = float_to_q16_16(5.0)
    dut.y1.value = float_to_q16_16(10.0)
    dut.x2.value = float_to_q16_16(10.0)
    dut.y2.value = float_to_q16_16(10.0)
    dut.x3.value = float_to_q16_16(10.0)
    dut.y3.value = float_to_q16_16(0.0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test case 1: Done signal not asserted within 25 cycles")
    
    if dut.can_hit.value != 1:
        raise TestFailure("Test case 1: Should be able to hit wall")
    
    result_y = q16_16_to_float(dut.y_wall.value)
    expected_y = 0.0
    
    if abs(result_y - expected_y) > 0.001:
        raise TestFailure(f"Test case 1: Expected y={expected_y}, got y={result_y}")
    
    dut._log.info(f"Test case 1 passed: y_wall = {result_y}")
    await RisingEdge(dut.clk)
    
    # Test Case 2: Mirror (5,10)-(10,5), Shooter (10,0)
    # Expected: wall hit at y=12.5
    dut.x1.value = float_to_q16_16(5.0)
    dut.y1.value = float_to_q16_16(10.0)
    dut.x2.value = float_to_q16_16(10.0)
    dut.y2.value = float_to_q16_16(5.0)
    dut.x3.value = float_to_q16_16(10.0)
    dut.y3.value = float_to_q16_16(0.0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test case 2: Done signal not asserted")
    
    if dut.can_hit.value != 1:
        raise TestFailure("Test case 2: Should be able to hit wall")
    
    result_y = q16_16_to_float(dut.y_wall.value)
    expected_y = 12.5
    
    if abs(result_y - expected_y) > 0.001:
        raise TestFailure(f"Test case 2: Expected y={expected_y}, got y={result_y}")
    
    dut._log.info(f"Test case 2 passed: y_wall = {result_y}")
    await RisingEdge(dut.clk)
    
    # Test Case 3: Mirror (6,10)-(10,10), Shooter (10,0)
    # Expected: can't hit wall
    dut.x1.value = float_to_q16_16(6.0)
    dut.y1.value = float_to_q16_16(10.0)
    dut.x2.value = float_to_q16_16(10.0)
    dut.y2.value = float_to_q16_16(10.0)
    dut.x3.value = float_to_q16_16(10.0)
    dut.y3.value = float_to_q16_16(0.0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test case 3: Done signal not asserted")
    
    if dut.can_hit.value != 0:
        raise TestFailure(f"Test case 3: Should NOT be able to hit wall, but can_hit={dut.can_hit.value}")
    
    dut._log.info("Test case 3 passed: correctly can't hit wall")
    await RisingEdge(dut.clk)
    
    # Test Case 4: Mirror (10,10)-(20,20), Shooter (20,10)
    # Expected: can't hit wall
    dut.x1.value = float_to_q16_16(10.0)
    dut.y1.value = float_to_q16_16(10.0)
    dut.x2.value = float_to_q16_16(20.0)
    dut.y2.value = float_to_q16_16(20.0)
    dut.x3.value = float_to_q16_16(20.0)
    dut.y3.value = float_to_q16_16(10.0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test case 4: Done signal not asserted")
    
    if dut.can_hit.value != 0:
        raise TestFailure(f"Test case 4: Should NOT be able to hit wall")
    
    dut._log.info("Test case 4 passed: correctly can't hit wall")
    await RisingEdge(dut.clk)
    
    dut._log.info("All 4 test cases passed!")