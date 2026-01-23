import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import math

# Helper functions for fixed-point conversion
def float_to_q1616(x):
    return int(x * 65536) & 0xFFFFFFFF

def q1616_to_float(x):
    if x & 0x80000000:  # negative
        return ((x & 0xFFFFFFFF) - 0x100000000) / 65536.0
    return x / 65536.0

def compute_kernel_area(vertices):
    """Compute kernel area for small polygon (up to 8 vertices)"""
    n = len(vertices)
    if n < 3:
        return 0.0
    
    # Start with the polygon itself as initial kernel
    kernel = list(vertices)
    
    # Process each edge
    for i in range(n):
        v1 = vertices[i]
        v2 = vertices[(i + 1) % n]
        
        # Edge vector
        edge_vec = (v2[0] - v1[0], v2[1] - v1[1])
        
        new_kernel = []
        m = len(kernel)
        
        if m == 0:
            return 0.0
        
        for j in range(m):
            p1 = kernel[j]
            p2 = kernel[(j + 1) % m]
            
            # Cross product to test which side
            cp1 = edge_vec[0] * (p1[1] - v1[1]) - edge_vec[1] * (p1[0] - v1[0])
            cp2 = edge_vec[0] * (p2[1] - v1[1]) - edge_vec[1] * (p2[0] - v1[0])
            
            # Check if inside (cross >= 0 for CCW polygon)
            # Note: polygon can be CW or CCW, but kernel test is consistent
            # We'll use the sign based on edge direction
            inside1 = cp1 >= -1e-10
            inside2 = cp2 >= -1e-10
            
            if inside2:
                if not inside1:
                    # p1 outside, p2 inside: add intersection
                    t = -cp1 / (cp2 - cp1 + 1e-15)
                    inter_x = p1[0] + t * (p2[0] - p1[0])
                    inter_y = p1[1] + t * (p2[1] - p1[1])
                    new_kernel.append((inter_x, inter_y))
                new_kernel.append(p2)
            elif inside1:
                # p1 inside, p2 outside: add intersection
                t = -cp1 / (cp2 - cp1 + 1e-15)
                inter_x = p1[0] + t * (p2[0] - p1[0])
                inter_y = p1[1] + t * (p2[1] - p1[1])
                new_kernel.append((inter_x, inter_y))
        
        kernel = new_kernel
        if len(kernel) < 3:
            return 0.0
    
    if len(kernel) < 3:
        return 0.0
    
    # Compute area using shoelace formula
    area = 0.0
    for i in range(len(kernel)):
        j = (i + 1) % len(kernel)
        area += kernel[i][0] * kernel[j][1]
        area -= kernel[j][0] * kernel[i][1]
    
    return abs(area) / 2.0

@cocotb.test()
async def test_polygon_kernel_area(dut):
    """Test polygon kernel area computation"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.vertex_count.value = 0
    for i in range(8):
        dut.vertex_x[i].value = 0
        dut.vertex_y[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Sample Input 1
    vertices1 = [(2.0, 0.0), (1.0, 1.0), (0.0, 2.0), (-2.0, 0.0), (0.0, -2.0)]
    expected_area1 = 8.0
    
    dut._log.info("Test 1: Pentagon with kernel")
    dut.vertex_count.value = 5
    for i, (x, y) in enumerate(vertices1):
        dut.vertex_x[i].value = float_to_q1616(x)
        dut.vertex_y[i].value = float_to_q1616(y)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test 1: Timeout - computation did not complete")
    
    if dut.error.value:
        raise TestFailure("Test 1: Error flag set")
    
    result = q1616_to_float(int(dut.area.value))
    dut._log.info(f"Test 1 Result: {result}, Expected: {expected_area1}")
    
    # Allow small error due to fixed-point precision
    if abs(result - expected_area1) > 0.01:
        raise TestFailure(f"Test 1 failed: got {result}, expected {expected_area1}")
    
    # Test case 2: Sample Input 2
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    vertices2 = [(0.2, 0.0), (0.0, -0.2), (0.0, 0.0), (-0.2, 0.0), (0.0, 0.2)]
    expected_area2 = 0.02
    
    dut._log.info("Test 2: Small star")
    dut.vertex_count.value = 5
    for i, (x, y) in enumerate(vertices2):
        dut.vertex_x[i].value = float_to_q1616(x)
        dut.vertex_y[i].value = float_to_q1616(y)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test 2: Timeout")
    
    if dut.error.value:
        raise TestFailure("Test 2: Error flag set")
    
    result = q1616_to_float(int(dut.area.value))
    dut._log.info(f"Test 2 Result: {result}, Expected: {expected_area2}")
    
    if abs(result - expected_area2) > 0.001:
        raise TestFailure(f"Test 2 failed: got {result}, expected {expected_area2}")
    
    # Test case 3: Empty kernel
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    vertices3 = [(0.0, 0.0), (5.0, 0.0), (2.0, 1.0), (5.0, 5.0), (0.0, 5.0), (3.0, 4.0)]
    expected_area3 = 0.0
    
    dut._log.info("Test 3: Empty kernel")
    dut.vertex_count.value = 6
    for i, (x, y) in enumerate(vertices3):
        dut.vertex_x[i].value = float_to_q1616(x)
        dut.vertex_y[i].value = float_to_q1616(y)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test 3: Timeout")
    
    # Should either have error or zero area
    if not dut.error.value:
        result = q1616_to_float(int(dut.area.value))
        if abs(result - expected_area3) > 0.001:
            raise TestFailure(f"Test 3 failed: got {result}, expected {expected_area3}")
    
    dut._log.info("Test 3 Result: Passed (empty kernel detected)")
    
    # Test case 4: Triangle (always fully visible)
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    vertices4 = [(0.0, 0.0), (2.0, 0.0), (1.0, 2.0)]
    # Area of triangle = 0.5 * 2 * 2 = 2.0
    expected_area4 = 2.0
    
    dut._log.info("Test 4: Triangle")
    dut.vertex_count.value = 3
    for i, (x, y) in enumerate(vertices4):
        dut.vertex_x[i].value = float_to_q1616(x)
        dut.vertex_y[i].value = float_to_q1616(y)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test 4: Timeout")
    
    if dut.error.value:
        raise TestFailure("Test 4: Error flag set")
    
    result = q1616_to_float(int(dut.area.value))
    dut._log.info(f"Test 4 Result: {result}, Expected: {expected_area4}")
    
    if abs(result - expected_area4) > 0.01:
        raise TestFailure(f"Test 4 failed: got {result}, expected {expected_area4}")
    
    # Test case 5: Square (full kernel)
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    vertices5 = [(0.0, 0.0), (2.0, 0.0), (2.0, 2.0), (0.0, 2.0)]
    expected_area5 = 4.0
    
    dut._log.info("Test 5: Square")
    dut.vertex_count.value = 4
    for i, (x, y) in enumerate(vertices5):
        dut.vertex_x[i].value = float_to_q1616(x)
        dut.vertex_y[i].value = float_to_q1616(y)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test 5: Timeout")
    
    if dut.error.value:
        raise TestFailure("Test 5: Error flag set")
    
    result = q1616_to_float(int(dut.area.value))
    dut._log.info(f"Test 5 Result: {result}, Expected: {expected_area5}")
    
    if abs(result - expected_area5) > 0.01:
        raise TestFailure(f"Test 5 failed: got {result}, expected {expected_area5}")
    
    dut._log.info("
=== All tests passed! ===")