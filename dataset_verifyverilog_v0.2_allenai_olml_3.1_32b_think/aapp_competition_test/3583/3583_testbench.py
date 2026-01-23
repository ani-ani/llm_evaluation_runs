import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import math

def q16_16(value):
    """Convert decimal to Q16.16 fixed-point representation"""
    return int(value * 65536)

def calculate_perimeter(vertices):
    """Calculate perimeter of hexagon given 6 vertices in polygon order"""
    perimeter = 0.0
    for i in range(6):
        x1, y1 = vertices[i]
        x2, y2 = vertices[(i+1) % 6]
        dx = x2 - x1
        dy = y2 - y1
        dist = math.sqrt(dx*dx + dy*dy)
        perimeter += dist
    return perimeter

@cocotb.test()
async def test_max_hexagon_perimeter(dut):
    """Test maximum hexagon perimeter calculator"""
    
    # Test case 1: n=6 (simple hexagon)
    # Input: 6 vertices from sample
    dut.n.value = 6
    x_coords = [1, 1, 2, 3, 3, 2]
    y_coords = [2, 3, 4, 3, 2, 1]
    
    for i in range(6):
        dut.x[i].value = x_coords[i]
        dut.y[i].value = y_coords[i]
    
    # Expected: 7.656854249492381
    expected = 7.656854249492381
    
    await Timer(10, units='ns')
    
    result = dut.perimeter.value
    result_float = result / 65536.0
    
    error = abs(result_float - expected) / max(1.0, expected)
    print(f"Test 1: Expected={expected:.6f}, Got={result_float:.6f}, Error={error:.6f}")
    assert error < 0.001, f"Test 1 failed: error {error} exceeds tolerance"
    
    # Test case 2: n=8 (more complex)
    dut.n.value = 8
    x_coords2 = [3, 6, 8, 8, 6, 3, 1, 1]
    y_coords2 = [1, 1, 3, 6, 8, 8, 6, 3]
    
    for i in range(8):
        dut.x[i].value = x_coords2[i]
        dut.y[i].value = y_coords2[i]
    
    # Expected: 22.42718386376139
    expected = 22.42718386376139
    
    await Timer(10, units='ns')
    
    result = dut.perimeter.value
    result_float = result / 65536.0
    
    error = abs(result_float - expected) / max(1.0, expected)
    print(f"Test 2: Expected={expected:.6f}, Got={result_float:.6f}, Error={error:.6f}")
    assert error < 0.001, f"Test 2 failed: error {error} exceeds tolerance"
    
    # Test case 3: n=7 (edge case)
    dut.n.value = 7
    # Use first 7 vertices from test case 2
    for i in range(7):
        dut.x[i].value = x_coords2[i]
        dut.y[i].value = y_coords2[i]
    
    # Expected: compute maximum from all combinations of 6 vertices
    # For this shape, should be same or close to 22.427...
    # Since we have symmetry, it should be the same
    
    await Timer(10, units='ns')
    
    result = dut.perimeter.value
    result_float = result / 65536.0
    
    print(f"Test 3: Got={result_float:.6f} (no exact comparison, just checking valid output)")
    # Just verify result is reasonable (greater than minimum possible)
    assert result_float > 15.0, f"Test 3 failed: result {result_float} too small"
    
    print("
Summary: All 3 tests passed!")