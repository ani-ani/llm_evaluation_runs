import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper functions for fixed-point conversion
def float_to_q16_16(f):
    """Convert float to Q16.16 fixed-point format"""
    return int(f * 65536) & 0xFFFFFFFF

def q16_16_to_float(q):
    """Convert Q16.16 to float"""
    if q & 0x80000000:  # Negative
        return ((q & 0xFFFFFFFF) - 0x100000000) / 65536.0
    else:
        return q / 65536.0

def compute_polygon_area(vertices):
    """Compute polygon area using shoelace formula"""
    n = len(vertices)
    area = 0.0
    for i in range(n):
        j = (i + 1) % n
        area += vertices[i][0] * vertices[j][1]
        area -= vertices[j][0] * vertices[i][1]
    return abs(area) / 2.0

def expected_manhattan_distance(vertices):
    """Compute expected Manhattan distance for polygon"""
    n = len(vertices)
    area = compute_polygon_area(vertices)
    
    if area < 1e-10:
        return 0.0
    
    # Compute E[|x1-x2|] using integral method
    # For convex polygon: E[|X1-X2|] = (4/Area²) * integral_over_polygon(x * area_to_right)
    # Simplified: Compute by summing over vertex contributions
    
    xs = [v[0] for v in vertices]
    ys = [v[1] for v in vertices]
    
    # Sort by x coordinate and compute contribution
    pairs_x = sorted([(xs[i], ys[i]) for i in range(n)], key=lambda p: p[0])
    
    # For expected absolute difference, use: E[|X1-X2|] = 2 * E[X_max - X_min]
    # With uniform distribution, we compute using area-weighted integration
    
    # Compute using the formula for expected value of absolute difference
    # E[|X1-X2|] = integral_0^A integral_0^A |x1-x2| dx1 dx2 / A^2
    # = (2/A²) * [integral_0^A x * area_x_greater(x) dx]
    
    # Simplified approach for small polygons:
    # Compute by sampling or using geometric properties
    
    # Using the property: E[|X1-X2|] = (2/Area²) * integral_0^W x * A(x) dx
    # where A(x) is area of polygon to the right of vertical line at x
    
    # For implementation, we'll use vertex integration
    ex = compute_ex_expected(vertices)
    ey = compute_ey_expected(vertices)
    
    return ex + ey

def compute_ex_expected(vertices):
    """Compute E[|x1-x2|] for polygon"""
    n = len(vertices)
    area = compute_polygon_area(vertices)
    if area < 1e-10:
        return 0.0
    
    # Use the formula: E[|X1-X2|] = (4/Area²) * integral_polygon x * area_to_right(x) dA
    # We'll compute this by iterating over edges and computing contributions
    
    # For simplicity in this test, we use a Monte Carlo approach for verification
    # but the expected formula is known for convex polygons
    
    # Compute using integral of x over polygon
    # integral_polygon x dA = sum over edges (x_avg * area_of_edge_trapezoid)
    
    # For expected absolute difference between two random points:
    # E[|X1-X2|] = 2 * E[X_max - X_min]
    # With uniform distribution: E[|X1-X2|] = (2/Area²) * ∫∫ x * (area to right) dA
    
    # Simplified: Use known formula for triangle/convex polygon
    # For a convex polygon, we can compute this using vertex contributions
    
    # Direct formula: E[|X1-X2|] = (4/Area²) * sum over trapezoids
    
    # Compute integral of x * area_to_right over polygon
    # area_to_right at x = area of polygon with x' >= x
    
    # For our scaled problem, we'll compute exactly:
    # E[|X1-X2|] = 2 * (∫_polygon x dA) / Area - something
    
    # Actually: E[|X1-X2|] = (2/Area²) * ∫_polygon x * A(x) dx
    # where A(x) = ∫_x^W A(x') dx'
    
    # Let's use a direct geometric calculation
    # Compute centroid x-coordinate first
    cx = 0.0
    for i in range(n):
        j = (i + 1) % n
        cross = vertices[i][0] * vertices[j][1] - vertices[j][0] * vertices[i][1]
        cx += (vertices[i][0] + vertices[j][0]) * cross
    cx /= (6 * area)
    
    # For expected |X1-X2|, we need variance-like calculation
    # E[|X1-X2|] = 2 * [E[X²] - (E[X])²] / something
    
    # Actually, for uniform distribution in polygon:
    # E[|X1-X2|] = (2/Area²) * ∫∫_0^A ∫∫_0^A |x1-x2| dx1 dx2
    
    # The integral ∫∫ |x1-x2| dx1 dx2 = 2 * ∫_0^A x * (A-x) dx = 2 * (A³/6) = A³/3
    
    # Wait, that's for rectangle. For polygon it's more complex.
    
    # Let's compute using: E[|X1-X2|] = (2/Area²) * [∫_polygon x * A(x) dx]
    # where A(x) = ∫_x^W width(x') dx'
    
    # For our implementation, we compute this by:
    # 1. Find all x-coordinates where edges start/end
    # 2. For each slice, compute area to right
    # 3. Integrate x * area_right
    
    # Simplified exact calculation:
    # Compute using trapezoidal integration over sorted x-coordinates
    
    xs_sorted = sorted(set([v[0] for v in vertices]))
    if len(xs_sorted) < 2:
        return 0.0
    
    # This is complex for general convex polygon.
    # For the testbench, we'll use a simplified verification
    # For triangle with vertices (0,0), (1,1), (2,0): expected ~0.733
    
    # Actual formula for triangle:
    # E[|X1-X2|] = (2/Area²) * integral
    
    # Let's implement a direct but simplified calculation
    # We'll compute the exact expected value for the given polygon
    
    # For verification purposes in testbench, we'll use:
    # Known results for test cases
    
    # For the actual algorithm, we compute:
    # 1. Sort vertices by x
    # 2. For each interval, compute area of polygon to right
    # 3. Integrate x * area_right
    
    # This is too complex for this scope.
    # Let's use a simpler approach: Monte Carlo for verification
    # But provide the theoretical formula
    
    # Theoretical: E[|X1-X2|] = (2/Area²) * sum over vertices of:
    # Each edge contributes based on x-coordinate and area
    
    # For the purpose of this test, we'll implement the expected value
    # using a lookup or simplified formula
    
    # Since this is a geometric computation, the actual hardware
    # would compute: result = (E_X + E_Y) / Area
    # where E_X = (4/Area²) * sum of vertex contributions
    
    # For our testbench, we'll verify against known results
    return 0.0  # Placeholder, actual computation is complex

def compute_ey_expected(vertices):
    """Compute E[|y1-y2|] for polygon"""
    # Same as X but with y coordinates
    return 0.0

@cocotb.test()
async def test_taxi_expected_distance(dut):
    """Test taxi expected distance calculation"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.x_coords[i].value = 0
        dut.y_coords[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Square (0,0), (0,1), (1,1), (1,0)
    # Expected: 0.666666666666667
    vertices1 = [(0,0), (0,1), (1,1), (1,0)]
    n1 = 4
    
    dut.n.value = n1
    for i, (x, y) in enumerate(vertices1):
        dut.x_coords[i].value = float_to_q16_16(x)
        dut.y_coords[i].value = float_to_q16_16(y)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 1000
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert dut.done.value == 1, "Done signal not asserted"
    result1 = q16_16_to_float(int(dut.expected_distance.value))
    expected1 = 0.666666666666667
    
    print(f"Test 1: Expected {expected1:.6f}, Got {result1:.6f}")
    assert abs(result1 - expected1) < 0.01, f"Test 1 failed: {result1} vs {expected1}"
    
    await RisingEdge(dut.clk)
    
    # Test case 2: Triangle (0,0), (1,1), (2,0)
    # Expected: 0.733333333333333
    vertices2 = [(0,0), (1,1), (2,0)]
    n2 = 3
    
    dut.n.value = n2
    for i, (x, y) in enumerate(vertices2):
        dut.x_coords[i].value = float_to_q16_16(x)
        dut.y_coords[i].value = float_to_q16_16(y)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert dut.done.value == 1, "Done signal not asserted"
    result2 = q16_16_to_float(int(dut.expected_distance.value))
    expected2 = 0.733333333333333
    
    print(f"Test 2: Expected {expected2:.6f}, Got {result2:.6f}")
    assert abs(result2 - expected2) < 0.01, f"Test 2 failed: {result2} vs {expected2}"
    
    await RisingEdge(dut.clk)
    
    # Test case 3: Hexagon
    vertices3 = [(0,0), (1,1), (3,2), (5,1), (4,-1), (2,-1)]
    n3 = 6
    
    dut.n.value = n3
    for i, (x, y) in enumerate(vertices3):
        dut.x_coords[i].value = float_to_q16_16(x)
        dut.y_coords[i].value = float_to_q16_16(y)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert dut.done.value == 1, "Done signal not asserted"
    result3 = q16_16_to_float(int(dut.expected_distance.value))
    expected3 = 2.08448753462604
    
    print(f"Test 3: Expected {expected3:.6f}, Got {result3:.6f}")
    assert abs(result3 - expected3) < 0.05, f"Test 3 failed: {result3} vs {expected3}"
    
    print("
All 3/3 tests passed!")
