import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def calculate_min_square(points):
    """Calculate min square side length for a set of points."""
    if len(points) == 0:
        return 0
    if len(points) == 1:
        return 0
    
    # Try all possible subsets (all or removing one)
    min_side = float('inf')
    
    # Case 1: No removal
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    side = max(max(xs) - min(xs), max(ys) - min(ys))
    min_side = min(min_side, side)
    
    # Case 2: Remove each house
    for i in range(len(points)):
        subset = points[:i] + points[i+1:]
        if len(subset) == 0:
            side = 0
        elif len(subset) == 1:
            side = 0
        else:
            xs = [p[0] for p in subset]
            ys = [p[1] for p in subset]
            side = max(max(xs) - min(xs), max(ys) - min(ys))
        min_side = min(min_side, side)
    
    return min_side

@cocotb.test()
async def test_min_square_with_ignore(dut):
    """Test the find_min_square_with_ignore module."""
    
    # Create a 10ns clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # Test case 1: From sample - 3 houses
        {
            'points': [(1, 0), (0, 1), (1000, 1)],
            'expected': 1
        },
        # Test case 2: From sample - 2 houses
        {
            'points': [(0, 1), (1000, 1)],
            'expected': 0
        },
        # Test case 3: 4 houses from example 2
        {
            'points': [(0, 0), (1000, 1000), (300, 300), (1, 1)],
            'expected': 300
        },
        # Test case 4: 3 houses from example 2 range 2-4
        {
            'points': [(1000, 1000), (300, 300), (1, 1)],
            'expected': 299
        },
        # Test case 5: Single house (edge case)
        {
            'points': [(100, 200)],
            'expected': 0
        },
        # Test case 6: Two houses at same location not allowed, so two houses close
        {
            'points': [(5, 5), (10, 10)],
            'expected': 5
        },
        # Test case 7: All same x, different y
        {
            'points': [(10, 0), (10, 100), (10, 200)],
            'expected': 0  # Can ignore one to make line, then remove all but one
        },
        # Test case 8: 3 houses in line
        {
            'points': [(0, 0), (5, 0), (10, 0)],
            'expected': 0
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, test in enumerate(test_cases):
        points = test['points']
        expected = test['expected']
        num_houses = len(points)
        
        # Pad to 8 houses with (0,0) if needed
        padded_points = points + [(0, 0)] * (8 - num_houses)
        
        # Set inputs
        dut.num_houses.value = num_houses
        dut.x0.value = padded_points[0][0]
        dut.y0.value = padded_points[0][1]
        dut.x1.value = padded_points[1][0]
        dut.y1.value = padded_points[1][1]
        dut.x2.value = padded_points[2][0]
        dut.y2.value = padded_points[2][1]
        dut.x3.value = padded_points[3][0]
        dut.y3.value = padded_points[3][1]
        dut.x4.value = padded_points[4][0]
        dut.y4.value = padded_points[4][1]
        dut.x5.value = padded_points[5][0]
        dut.y5.value = padded_points[5][1]
        dut.x6.value = padded_points[6][0]
        dut.y6.value = padded_points[6][1]
        dut.x7.value = padded_points[7][0]
        dut.y7.value = padded_points[7][1]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
        
        # Read result
        result = int(dut.result.value)
        
        if result == expected:
            passed += 1
            dut._log.info(f"Test {i+1} PASSED: points={points}, expected={expected}, got={result}")
        else:
            dut._log.error(f"Test {i+1} FAILED: points={points}, expected={expected}, got={result}")
    
    dut._log.info(f"
SUMMARY: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Not all tests passed: {passed}/{total}")
