import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def cross_product(ax, ay, bx, by):
    return ax * by - ay * bx

def point_in_convex_polygon(vertices, point):
    """Check if point is strictly inside convex polygon"""
    n = len(vertices)
    if n < 3:
        return False
    
    # Determine orientation
    signs = []
    for i in range(n):
        x1, y1 = vertices[i]
        x2, y2 = vertices[(i+1)%n]
        xp, yp = point
        
        cross = cross_product(x2-x1, y2-y1, xp-x1, yp-y1)
        if cross == 0:
            return False  # On edge
        signs.append(cross > 0)
    
    # All signs should be same
    return all(signs) or not any(signs)

@cocotb.test()
async def test_min_vertices_finder(dut):
    """Test min vertices finder with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    test_cases = [
        {
            'vertices': [(0, 0), (0, 3), (3, 3), (3, 0)],
            'points': [(1, 1), (2, 2)],
            'expected': 4
        },
        {
            'vertices': [(3, 0), (7, 0), (10, 3), (10, 7), (7, 10), (3, 10), (0, 7), (0, 3)],
            'points': [(1, 3), (3, 3), (5, 3), (7, 3), (9, 3), (3, 5), (5, 5), (7, 5), (5, 7), (7, 7), (7, 9)],
            'expected': 4
        },
        {
            'vertices': [(0, 0), (4, 0), (4, 4), (0, 4)],
            'points': [(1, 1)],
            'expected': 4  # Still need all 4 as 1 point is inside any quad
        },
        {
            'vertices': [(0, 0), (5, 0), (5, 5), (0, 5)],
            'points': [(2, 1), (3, 1)],
            'expected': 4  # All points on same side, but need 4 for convex hull
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        dut._log.info(f"Running test case {i+1}/{total}")
        
        # Convert to Q16.16 format
        def to_q16_16(val):
            return int(val * 65536)
        
        N = len(tc['vertices'])
        K = len(tc['points'])
        
        # Load inputs
        dut.N.value = N
        dut.K.value = K
        
        # Set vertices
        for idx, (x, y) in enumerate(tc['vertices']):
            val = (to_q16_16(x) << 32) | (to_q16_16(y) & 0xFFFFFFFF)
            dut.vertices[idx].value = val
        
        # Set points
        for idx, (x, y) in enumerate(tc['points']):
            val = (to_q16_16(x) << 32) | (to_q16_16(y) & 0xFFFFFFFF)
            dut.points[idx].value = val
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 10000
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done")
        
        # Get result
        result = int(dut.result.value)
        
        if result == tc['expected']:
            dut._log.info(f"Test {i+1}: PASS (result={result})")
            passed += 1
        else:
            dut._log.error(f"Test {i+1}: FAIL (got {result}, expected {tc['expected']})")
    
    dut._log.info(f"
Summary: {passed}/{total} tests passed")
    
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
