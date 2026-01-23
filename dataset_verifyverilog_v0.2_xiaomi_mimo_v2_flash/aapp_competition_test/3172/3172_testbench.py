import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import math

# Helper function to convert float to Q16.16 fixed-point
def float_to_q16_16(val):
    return int(val * 65536) & 0xFFFFFFFF

@cocotb.test()
async def test_fruit_slicer_basic(dut):
    """Test basic functionality with 3 points forming a triangle"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_circles.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case 2: 3 points forming triangle (should all be slicable)
    # (-1.50, -1.00), (1.50, -1.00), (0.00, 1.00)
    points = [(-1.5, -1.0), (1.5, -1.0), (0.0, 1.0)]
    for i, (x, y) in enumerate(points):
        dut.circle_x[i].value = float_to_q16_16(x)
        dut.circle_y[i].value = float_to_q16_16(y)
    dut.num_circles.value = 3
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Check result
    result = int(dut.max_slices.value)
    print(f"Test 1 - Triangle: Got {result}, Expected 3")
    assert result >= 3, f"Expected at least 3, got {result}"

@cocotb.test()
async def test_fruit_slicer_sample1(dut):
    """Test with sample input 1 (5 points, expect 4)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Points: (1,5), (3,3), (4,2), (6,4.5), (7,1)
    points = [(1.0, 5.0), (3.0, 3.0), (4.0, 2.0), (6.0, 4.5), (7.0, 1.0)]
    for i, (x, y) in enumerate(points):
        dut.circle_x[i].value = float_to_q16_16(x)
        dut.circle_y[i].value = float_to_q16_16(y)
    dut.num_circles.value = 5
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.max_slices.value)
    print(f"Test 2 - Sample 1: Got {result}, Expected 4")
    assert result >= 4, f"Expected at least 4, got {result}"

@cocotb.test()
async def test_fruit_slicer_coincident(dut):
    """Test with overlapping circles (2 points same location)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Two points at (1, 1)
    dut.circle_x[0].value = float_to_q16_16(1.0)
    dut.circle_y[0].value = float_to_q16_16(1.0)
    dut.circle_x[1].value = float_to_q16_16(1.0)
    dut.circle_y[1].value = float_to_q16_16(1.0)
    dut.num_circles.value = 2
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.max_slices.value)
    print(f"Test 3 - Coincident: Got {result}, Expected 2")
    assert result >= 2, f"Expected at least 2, got {result}"

@cocotb.test()
async def test_fruit_slicer_single(dut):
    """Test with single circle"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    dut.circle_x[0].value = float_to_q16_16(5.0)
    dut.circle_y[0].value = float_to_q16_16(5.0)
    dut.num_circles.value = 1
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.max_slices.value)
    print(f"Test 4 - Single: Got {result}, Expected 1")
    assert result >= 1, f"Expected at least 1, got {result}"

@cocotb.test()
async def test_fruit_slicer_colinear(dut):
    """Test with 4 points almost colinear"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Points on line y = x: (0,0), (1,1), (2,2), (3,3)
    points = [(0.0, 0.0), (1.0, 1.0), (2.0, 2.0), (3.0, 3.0)]
    for i, (x, y) in enumerate(points):
        dut.circle_x[i].value = float_to_q16_16(x)
        dut.circle_y[i].value = float_to_q16_16(y)
    dut.num_circles.value = 4
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.max_slices.value)
    print(f"Test 5 - Colinear: Got {result}, Expected 4")
    assert result >= 4, f"Expected at least 4, got {result}"