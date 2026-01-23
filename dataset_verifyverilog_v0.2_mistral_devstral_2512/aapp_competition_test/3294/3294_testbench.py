import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

# Fixed-point conversion helpers
Q12_4_SCALE = 16  # 2^4
Q16_16_SCALE = 65536  # 2^16

def to_q12_4(value):
    return int(value * Q12_4_SCALE)

def to_q16_16(value):
    return int(value * Q16_16_SCALE)

def from_q16_16(value):
    return value / Q16_16_SCALE

# Expected calculation
def calc_distance(x, y):
    return math.sqrt(x*x + y*y)

def calc_min_distance(poly):
    min_dist = float('inf')
    n = len(poly)
    
    # Check vertices
    for x, y in poly:
        d = calc_distance(x, y)
        min_dist = min(min_dist, d)
    
    # Check edges
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i+1) % n]
        
        # Edge vector
        dx = x2 - x1
        dy = y2 - y1
        
        # Edge length squared
        len_sq = dx*dx + dy*dy
        
        if len_sq == 0:
            continue
        
        # Projection parameter t of origin onto line
        # t = - (x1*dx + y1*dy) / (dx*dx + dy*dy)
        dot = x1*dx + y1*dy
        t = -dot / len_sq
        
        if 0 <= t <= 1:
            # Perpendicular to segment
            px = x1 + t*dx
            py = y1 + t*dy
            d = calc_distance(px, py)
        else:
            # Endpoints
            d1 = calc_distance(x1, y1)
            d2 = calc_distance(x2, y2)
            d = min(d1, d2)
        
        min_dist = min(min_dist, d)
    
    return min_dist

@cocotb.test()
async def test_shortest_path(dut):
    """Test shortest distance calculation for polygon boundaries"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # Case 1: Square at (0,0) offset, 4 vertices
        {
            'poly': [(-2, 0), (0, -3), (2, 0), (0, 3)],
            'name': 'Diamond at origin'
        },
        # Case 2: Triangle with point close to origin
        {
            'poly': [(-14, -14), (14, -14), (0, 20)],
            'name': 'Triangle'
        },
        # Case 3: Complex polygon
        {
            'poly': [(-4, -4), (-1, -3), (-2, 2), (2, 2), (1, -3), (4, -4), (3, 4), (-3, 4)],
            'name': 'Complex 8-vertex'
        },
        # Case 4: Small square
        {
            'poly': [(1, 0), (0, 1), (-1, 0), (0, -1)],
            'name': 'Small diamond'
        },
        # Case 5: Horizontal line segments
        {
            'poly': [(-2, 1), (2, 1), (2, -1), (-2, -1)],
            'name': 'Rectangle'
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        poly = tc['poly']
        n = len(poly)
        
        print(f"
Test {i+1}: {tc['name']}")
        print(f"  Polygon vertices: {poly}")
        
        # Load vertex coordinates
        for j in range(8):
            if j < n:
                x_q = to_q12_4(poly[j][0])
                y_q = to_q12_4(poly[j][1])
            else:
                x_q = 0
                y_q = 0
            
            # Access arrays by index
            dut.poly_x[j].value = x_q
            dut.poly_y[j].value = y_q
        
        dut.vertex_count.value = n
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 300
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            print(f"  FAILED: Timeout after {timeout} cycles")
            continue
        
        # Read result
        result_q = int(dut.min_distance.value)
        result = from_q16_16(result_q)
        
        # Expected
        expected = calc_min_distance(poly)
        
        print(f"  Result: {result:.10f}")
        print(f"  Expected: {expected:.10f}")
        
        # Check with tolerance
        if abs(result - expected) < 1e-3:
            print(f"  PASSED")
            passed += 1
        else:
            print(f"  FAILED: diff={abs(result - expected):.6f}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
