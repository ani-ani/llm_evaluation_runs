import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def combinations(arr, r):
    # Generator for combinations
    from itertools import combinations
    return combinations(arr, r)

def calculate_area_2x(points):
    # points is a list of (x, y) tuples
    # Compute 2 * Area of polygon using Shoelace formula
    n = len(points)
    area = 0
    for i in range(n):
        x1, y1 = points[i]
        x2, y2 = points[(i + 1) % n]
        area += (x1 * y2 - x2 * y1)
    return abs(area)

@cocotb.test()
def test_quadrilateral_game_score(dut):
    """Test quadrilateral game score computation with N=8 fixed points"""
    
    # Generate 8 random but distinct points (scaled to fit 12-bit signed range)
    random.seed(42)
    points = set()
    while len(points) < 8:
        x = random.randint(-100, 100)
        y = random.randint(-100, 100)
        # Ensure no three collinear by checking, but random is usually fine
        points.add((x, y))
    
    points = list(points)
    
    # Prepare inputs for DUT
    # dut.x_i and dut.y_i are arrays
    for i in range(8):
        dut.x_i[i].value = points[i][0]
        dut.y_i[i].value = points[i][1]
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Done signal not asserted within timeout"
    
    # Calculate expected score in Python
    # Iterate all combinations of 4 points
    indices = list(range(8))
    expected_score = 0
    mod = 1000003
    
    from itertools import combinations
    for combo in combinations(indices, 4):
        quad_points = [points[i] for i in combo]
        area2x = calculate_area_2x(quad_points)
        expected_score = (expected_score + area2x) % mod
    
    # Check result
    dut_score = int(dut.total_score.value)
    
    print(f"
Test Points: {points}")
    print(f"Expected Total Score (mod {mod}): {expected_score}")
    print(f"DUT Total Score: {dut_score}")
    
    assert dut_score == expected_score, f"Mismatch! Expected {expected_score}, got {dut_score}"
    print(f"1/1 tests passed")
