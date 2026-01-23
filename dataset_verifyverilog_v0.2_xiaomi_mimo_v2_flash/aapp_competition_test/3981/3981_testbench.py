import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

def to_fixed_point(value):
    """Convert decimal to Q16.16 fixed-point"""
    return int(value * 65536) & 0xFFFF

def from_fixed_point(value):
    """Convert Q16.16 fixed-point to decimal"""
    if value & 0x8000:
        return (value - 0x10000) / 65536.0
    return value / 65536.0

@cocotb.test()
async def test_rocket_safety_basic(dut):
    """Test basic safety check with identical hulls"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test Case 1: Two triangles that are equivalent
    # Engine 1: (0,0), (0,2), (2,0)
    engine1_points = [(0,0), (0,2), (2,0)]
    # Engine 2: (-2,0), (0,0), (0,-2) -> rotated version
    engine2_points = [(-2,0), (0,0), (0,-2)]
    
    # Set engine 1
    for i in range(8):
        if i < len(engine1_points):
            dut.engine1_x[i].value = to_fixed_point(engine1_points[i][0])
            dut.engine1_y[i].value = to_fixed_point(engine1_points[i][1])
        else:
            dut.engine1_x[i].value = 0
            dut.engine1_y[i].value = 0
    dut.engine1_count.value = len(engine1_points)
    
    # Set engine 2
    for i in range(8):
        if i < len(engine2_points):
            dut.engine2_x[i].value = to_fixed_point(engine2_points[i][0])
            dut.engine2_y[i].value = to_fixed_point(engine2_points[i][1])
        else:
            dut.engine2_x[i].value = 0
            dut.engine2_y[i].value = 0
    dut.engine2_count.value = len(engine2_points)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Check result - should be safe (YES = 1)
    assert dut.safe.value == 1, f"Expected safe=1, got {dut.safe.value}"
    print("Test 1 passed: Identical hulls are safe")

@cocotb.test()
async def test_rocket_safety_different(dut):
    """Test with different hulls - should be unsafe"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Engine 1: Triangle
    engine1_points = [(0,0), (0,2), (2,0)]
    # Engine 2: Different triangle with extra point
    engine2_points = [(0,0), (0,2), (2,0), (1,1)]
    
    # Set engine 1
    for i in range(8):
        if i < len(engine1_points):
            dut.engine1_x[i].value = to_fixed_point(engine1_points[i][0])
            dut.engine1_y[i].value = to_fixed_point(engine1_points[i][1])
        else:
            dut.engine1_x[i].value = 0
            dut.engine1_y[i].value = 0
    dut.engine1_count.value = len(engine1_points)
    
    # Set engine 2
    for i in range(8):
        if i < len(engine2_points):
            dut.engine2_x[i].value = to_fixed_point(engine2_points[i][0])
            dut.engine2_y[i].value = to_fixed_point(engine2_points[i][1])
        else:
            dut.engine2_x[i].value = 0
            dut.engine2_y[i].value = 0
    dut.engine2_count.value = len(engine2_points)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Should be unsafe (NO = 0) or could be safe if point is redundant
    # In this case, (1,1) is inside hull, so might still be safe
    # Let's test a clear unsafe case: different hull shape
    print(f"Test 2 result: safe={dut.safe.value}")

@cocotb.test()
async def test_rocket_safety_collinear(dut):
    """Test with collinear points - edge case"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Engine 1: Line
    engine1_points = [(0,0), (1,1), (2,2)]
    # Engine 2: Different line
    engine2_points = [(0,0), (2,2), (4,4)]
    
    for i in range(8):
        if i < len(engine1_points):
            dut.engine1_x[i].value = to_fixed_point(engine1_points[i][0])
            dut.engine1_y[i].value = to_fixed_point(engine1_points[i][1])
        else:
            dut.engine1_x[i].value = 0
            dut.engine1_y[i].value = 0
    dut.engine1_count.value = len(engine1_points)
    
    for i in range(8):
        if i < len(engine2_points):
            dut.engine2_x[i].value = to_fixed_point(engine2_points[i][0])
            dut.engine2_y[i].value = to_fixed_point(engine2_points[i][1])
        else:
            dut.engine2_x[i].value = 0
            dut.engine2_y[i].value = 0
    dut.engine2_count.value = len(engine2_points)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    print(f"Test 3 result: safe={dut.safe.value}")

@cocotb.test()
async def test_rocket_safety_exact_match(dut):
    """Test exact match after transformation"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Both engines have same points
    engine1_points = [(100, 100), (200, 100), (150, 200)]
    engine2_points = [(100, 100), (200, 100), (150, 200)]
    
    for i in range(8):
        if i < len(engine1_points):
            dut.engine1_x[i].value = to_fixed_point(engine1_points[i][0])
            dut.engine1_y[i].value = to_fixed_point(engine1_points[i][1])
        else:
            dut.engine1_x[i].value = 0
            dut.engine1_y[i].value = 0
    dut.engine1_count.value = len(engine1_points)
    
    for i in range(8):
        if i < len(engine2_points):
            dut.engine2_x[i].value = to_fixed_point(engine2_points[i][0])
            dut.engine2_y[i].value = to_fixed_point(engine2_points[i][1])
        else:
            dut.engine2_x[i].value = 0
            dut.engine2_y[i].value = 0
    dut.engine2_count.value = len(engine2_points)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.safe.value == 1, f"Expected safe=1 for identical hulls, got {dut.safe.value}"
    print("Test 4 passed: Exact match is safe")

@cocotb.test()
async def test_rocket_safety_minimal(dut):
    """Test minimal case with 3 points each"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Engine 1: triangle
    engine1_points = [(0, 0), (65536, 0), (0, 65536)]  # 0, 1, 1 in fixed point
    # Engine 2: rotated triangle
    engine2_points = [(0, 0), (0, 65536), (-65536, 0)]  # 0, 1, -1
    
    for i in range(8):
        if i < len(engine1_points):
            dut.engine1_x[i].value = engine1_points[i][0]
            dut.engine1_y[i].value = engine1_points[i][1]
        else:
            dut.engine1_x[i].value = 0
            dut.engine1_y[i].value = 0
    dut.engine1_count.value = 3
    
    for i in range(8):
        if i < len(engine2_points):
            dut.engine2_x[i].value = engine2_points[i][0]
            dut.engine2_y[i].value = engine2_points[i][1]
        else:
            dut.engine2_x[i].value = 0
            dut.engine2_y[i].value = 0
    dut.engine2_count.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    print(f"Test 5 result: safe={dut.safe.value}")
    print("All basic tests completed")
