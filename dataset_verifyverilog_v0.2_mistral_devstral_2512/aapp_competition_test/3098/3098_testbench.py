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
    if value & 0x80000000:  # negative
        return (value - 0x100000000) / 65536.0
    else:
        return value / 65536.0

def compute_triangle_area(x1, y1, x2, y2, x3, y3):
    """Compute signed area of triangle using shoelace"""
    # In Q16.16, result is also in Q16.16
    cross = x1*y2 + x2*y3 + x3*y1 - x2*y1 - x3*y2 - x1*y3
    area = cross // 2
    return area

def compute_expected_area(vertices, n, k):
    """Compute expected area for n vertices and k selection"""
    from itertools import combinations
    total_area = 0
    count = 0
    for combo in combinations(range(n), k):
        # Get vertices in clockwise order
        pts = [vertices[i] for i in combo]
        # Sort by index to maintain order, but for triangle just compute
        x1, y1 = pts[0]
        x2, y2 = pts[1]
        x3, y3 = pts[2]
        area = compute_triangle_area(x1, y1, x2, y2, x3, y3)
        total_area += abs(area)
        count += 1
    # Divide by count (C(n,k)) and also divide by 2 (shoelace gives double area)
    # Actually area formula includes /2, but we did //2 in compute_triangle_area
    # So expected = total / count
    expected = total_area / count
    return expected

@cocotb.test()
async def test_expected_area_basic(dut):
    """Test expected area computation with sample inputs"""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.k.value = 0
    dut.x0.value = 0
    dut.y0.value = 0
    dut.x1.value = 0
    dut.y1.value = 0
    dut.x2.value = 0
    dut.y2.value = 0
    dut.x3.value = 0
    dut.y3.value = 0
    dut.x4.value = 0
    dut.y4.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=4, k=3 from sample
    # Vertices: (0,0), (1,1), (2,1), (1,0) -> clockwise
    vertices_1 = [
        (0, 0),
        (1, 1),
        (2, 1),
        (1, 0)
    ]
    
    # Expected: 0.5, in Q16.16: 0.5 * 65536 = 32768
    
    dut.n.value = 4
    dut.k.value = 3
    dut.x0.value = float_to_q16_16(0.0)
    dut.y0.value = float_to_q16_16(0.0)
    dut.x1.value = float_to_q16_16(1.0)
    dut.y1.value = float_to_q16_16(1.0)
    dut.x2.value = float_to_q16_16(2.0)
    dut.y2.value = float_to_q16_16(1.0)
    dut.x3.value = float_to_q16_16(1.0)
    dut.y3.value = float_to_q16_16(0.0)
    dut.x4.value = float_to_q16_16(0.0)  # unused
    dut.y4.value = float_to_q16_16(0.0)  # unused
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 200
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    result_float = q16_16_to_float(result)
    
    print(f"Test 1 - Result: {result_float} (Q16.16: {result}), Expected: 0.5")
    
    # Allow small error due to fixed-point arithmetic
    if abs(result_float - 0.5) > 0.01:
        raise TestFailure(f"Result {result_float} differs from expected 0.5")
    
    # Test case 2: n=5, k=5 from sample
    # Expected: 12.5
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 5
    dut.k.value = 5
    dut.x0.value = float_to_q16_16(0.0)
    dut.y0.value = float_to_q16_16(4.0)
    dut.x1.value = float_to_q16_16(4.0)
    dut.y1.value = float_to_q16_16(2.0)
    dut.x2.value = float_to_q16_16(4.0)
    dut.y2.value = float_to_q16_16(1.0)
    dut.x3.value = float_to_q16_16(3.0)
    dut.y3.value = float_to_q16_16(-1.0)
    dut.x4.value = float_to_q16_16(-2.0)
    dut.y4.value = float_to_q16_16(4.0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 200
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    result_float = q16_16_to_float(result)
    
    print(f"Test 2 - Result: {result_float} (Q16.16: {result}), Expected: 12.5")
    
    if abs(result_float - 12.5) > 0.01:
        raise TestFailure(f"Result {result_float} differs from expected 12.5")
    
    # Test case 3: n=5, k=3 from sample
    # Expected: 12.433
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 5
    dut.k.value = 3
    dut.x0.value = float_to_q16_16(-1.20)
    dut.y0.value = float_to_q16_16(2.80)
    dut.x1.value = float_to_q16_16(3.30)
    dut.y1.value = float_to_q16_16(2.40)
    dut.x2.value = float_to_q16_16(3.10)
    dut.y2.value = float_to_q16_16(-0.80)
    dut.x3.value = float_to_q16_16(2.00)
    dut.y3.value = float_to_q16_16(-4.60)
    dut.x4.value = float_to_q16_16(-4.40)
    dut.y4.value = float_to_q16_16(-0.50)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 200
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    result_float = q16_16_to_float(result)
    
    print(f"Test 3 - Result: {result_float} (Q16.16: {result}), Expected: 12.433")
    
    if abs(result_float - 12.433) > 0.1:
        raise TestFailure(f"Result {result_float} differs from expected 12.433")
    
    print("All tests passed!")
