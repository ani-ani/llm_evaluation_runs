import cocotb
from cocotb.triggers import Timer
import random

# Helper function to convert float to Q16.16 fixed point
def to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# Helper function to check if point is inside quadrilateral
def is_point_in_quad(px, py, n1, n2, n3, n4):
    # Check if point is inside or on border of convex quadrilateral
    # Using cross product tests
    def cross(ax, ay, bx, by, cx, cy):
        return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
    
    # Check all 4 edges
    # Edge n1-n2
    d1 = cross(n1[0], n1[1], n2[0], n2[1], px, py)
    # Edge n2-n3
    d2 = cross(n2[0], n2[1], n3[0], n3[1], px, py)
    # Edge n3-n4
    d3 = cross(n3[0], n3[1], n4[0], n4[1], px, py)
    # Edge n4-n1
    d4 = cross(n4[0], n4[1], n1[0], n1[1], px, py)
    
    # All must be >= 0 or all <= 0 (including 0 for on border)
    # But quadrilateral might not be in consistent order
    # So we need to check both possibilities
    all_non_neg = (d1 >= -1 and d2 >= -1 and d3 >= -1 and d4 >= -1)
    all_non_pos = (d1 <= 1 and d2 <= 1 and d3 <= 1 and d4 <= 1)
    
    return all_non_neg or all_non_pos

@cocotb.test()
async def test_castle_danger_basic(dut):
    """Test basic case with 4 Nazi troops and 4 castles"""
    
    # Test case from sample:
    # Nazi: (0,1), (3,7), (4,5), (6,5)
    # Castles: (1,4) - in danger (should be inside)
    #          (1,6) - in danger  
    #          (2,3) - in danger
    #          (2,5) - in danger
    
    nazi_points = [(0,1), (3,7), (4,5), (6,5)]
    castle_points = [(1,4), (1,6), (2,3), (2,5)]
    expected_danger = 0b1111  # All 4 in danger
    
    # Set inputs
    dut.n1_x.value = to_q16_16(nazi_points[0][0])
    dut.n1_y.value = to_q16_16(nazi_points[0][1])
    dut.n2_x.value = to_q16_16(nazi_points[1][0])
    dut.n2_y.value = to_q16_16(nazi_points[1][1])
    dut.n3_x.value = to_q16_16(nazi_points[2][0])
    dut.n3_y.value = to_q16_16(nazi_points[2][1])
    dut.n4_x.value = to_q16_16(nazi_points[3][0])
    dut.n4_y.value = to_q16_16(nazi_points[3][1])
    
    dut.c1_x.value = to_q16_16(castle_points[0][0])
    dut.c1_y.value = to_q16_16(castle_points[0][1])
    dut.c2_x.value = to_q16_16(castle_points[1][0])
    dut.c2_y.value = to_q16_16(castle_points[1][1])
    dut.c3_x.value = to_q16_16(castle_points[2][0])
    dut.c3_y.value = to_q16_16(castle_points[2][1])
    dut.c4_x.value = to_q16_16(castle_points[3][0])
    dut.c4_y.value = to_q16_16(castle_points[3][1])
    
    # Wait for combinational logic
    await Timer(10, units='ns')
    
    result = int(dut.danger.value)
    print(f"Result: {result:04b}, Expected: {expected_danger:04b}")
    assert result == expected_danger, f"Expected {expected_danger:04b}, got {result:04b}"

@cocotb.test()
async def test_castle_danger_outside(dut):
    """Test case where castles are outside"""
    
    # Nazi: (1,2), (3,2), (5,2), (2,5) - forms a quadrilateral
    # Castles: (3,4) - outside, (2,3) - inside
    
    nazi_points = [(1,2), (3,2), (5,2), (2,5)]
    castle_points = [(3,4), (2,3), (10,10), (0,0)]
    expected_danger = 0b0010  # Only castle 2 is in danger (index 1 -> bit 1)
    
    dut.n1_x.value = to_q16_16(nazi_points[0][0])
    dut.n1_y.value = to_q16_16(nazi_points[0][1])
    dut.n2_x.value = to_q16_16(nazi_points[1][0])
    dut.n2_y.value = to_q16_16(nazi_points[1][1])
    dut.n3_x.value = to_q16_16(nazi_points[2][0])
    dut.n3_y.value = to_q16_16(nazi_points[2][1])
    dut.n4_x.value = to_q16_16(nazi_points[3][0])
    dut.n4_y.value = to_q16_16(nazi_points[3][1])
    
    dut.c1_x.value = to_q16_16(castle_points[0][0])
    dut.c1_y.value = to_q16_16(castle_points[0][1])
    dut.c2_x.value = to_q16_16(castle_points[1][0])
    dut.c2_y.value = to_q16_16(castle_points[1][1])
    dut.c3_x.value = to_q16_16(castle_points[2][0])
    dut.c3_y.value = to_q16_16(castle_points[2][1])
    dut.c4_x.value = to_q16_16(castle_points[3][0])
    dut.c4_y.value = to_q16_16(castle_points[3][1])
    
    await Timer(10, units='ns')
    
    result = int(dut.danger.value)
    print(f"Result: {result:04b}, Expected: {expected_danger:04b}")
    assert result == expected_danger, f"Expected {expected_danger:04b}, got {result:04b}"

@cocotb.test()
async def test_castle_danger_on_border(dut):
    """Test case where castle is on border"""
    
    # Nazi: (0,0), (4,0), (4,4), (0,4) - square
    # Castle: (2,0) - on bottom edge (should be in danger)
    
    nazi_points = [(0,0), (4,0), (4,4), (0,4)]
    castle_points = [(2,0), (4,2), (2,4), (0,2)]  # All on edges
    expected_danger = 0b1111  # All on border = in danger
    
    dut.n1_x.value = to_q16_16(nazi_points[0][0])
    dut.n1_y.value = to_q16_16(nazi_points[0][1])
    dut.n2_x.value = to_q16_16(nazi_points[1][0])
    dut.n2_y.value = to_q16_16(nazi_points[1][1])
    dut.n3_x.value = to_q16_16(nazi_points[2][0])
    dut.n3_y.value = to_q16_16(nazi_points[2][1])
    dut.n4_x.value = to_q16_16(nazi_points[3][0])
    dut.n4_y.value = to_q16_16(nazi_points[3][1])
    
    dut.c1_x.value = to_q16_16(castle_points[0][0])
    dut.c1_y.value = to_q16_16(castle_points[0][1])
    dut.c2_x.value = to_q16_16(castle_points[1][0])
    dut.c2_y.value = to_q16_16(castle_points[1][1])
    dut.c3_x.value = to_q16_16(castle_points[2][0])
    dut.c3_y.value = to_q16_16(castle_points[2][1])
    dut.c4_x.value = to_q16_16(castle_points[3][0])
    dut.c4_y.value = to_q16_16(castle_points[3][1])
    
    await Timer(10, units='ns')
    
    result = int(dut.danger.value)
    print(f"Result: {result:04b}, Expected: {expected_danger:04b}")
    assert result == expected_danger, f"Expected {expected_danger:04b}, got {result:04b}"

@cocotb.test()
async def test_castle_danger_complex(dut):
    """Test with non-rectangular quadrilateral"""
    
    # Nazi: (0,0), (5,1), (4,4), (1,3)
    # Castle: (2,2) - inside
    # Castle: (6,2) - outside
    
    nazi_points = [(0,0), (5,1), (4,4), (1,3)]
    castle_points = [(2,2), (6,2), (2,1), (4,3)]
    expected_danger = 0b1111  # First 3 inside, last one on vertex (still in danger)
    
    dut.n1_x.value = to_q16_16(nazi_points[0][0])
    dut.n1_y.value = to_q16_16(nazi_points[0][1])
    dut.n2_x.value = to_q16_16(nazi_points[1][0])
    dut.n2_y.value = to_q16_16(nazi_points[1][1])
    dut.n3_x.value = to_q16_16(nazi_points[2][0])
    dut.n3_y.value = to_q16_16(nazi_points[2][1])
    dut.n4_x.value = to_q16_16(nazi_points[3][0])
    dut.n4_y.value = to_q16_16(nazi_points[3][1])
    
    dut.c1_x.value = to_q16_16(castle_points[0][0])
    dut.c1_y.value = to_q16_16(castle_points[0][1])
    dut.c2_x.value = to_q16_16(castle_points[1][0])
    dut.c2_y.value = to_q16_16(castle_points[1][1])
    dut.c3_x.value = to_q16_16(castle_points[2][0])
    dut.c3_y.value = to_q16_16(castle_points[2][1])
    dut.c4_x.value = to_q16_16(castle_points[3][0])
    dut.c4_y.value = to_q16_16(castle_points[3][1])
    
    await Timer(10, units='ns')
    
    result = int(dut.danger.value)
    print(f"Result: {result:04b}, Expected: {expected_danger:04b}")
    assert result == expected_danger, f"Expected {expected_danger:04b}, got {result:04b}"

@cocotb.test()
async def test_castle_danger_boundary(dut):
    """Test boundary values and precision"""
    
    # Test with values near max of Q16.16 range
    # Nazi: (0.1, 0.1), (100.5, 0.1), (100.5, 100.5), (0.1, 100.5)
    # Castle: (50.25, 50.25) - inside
    
    nazi_points = [(0.1, 0.1), (100.5, 0.1), (100.5, 100.5), (0.1, 100.5)]
    castle_points = [(50.25, 50.25), (0,0), (100,100), (200,200)]
    expected_danger = 0b1001  # First and fourth inside/on border
    
    dut.n1_x.value = to_q16_16(nazi_points[0][0])
    dut.n1_y.value = to_q16_16(nazi_points[0][1])
    dut.n2_x.value = to_q16_16(nazi_points[1][0])
    dut.n2_y.value = to_q16_16(nazi_points[1][1])
    dut.n3_x.value = to_q16_16(nazi_points[2][0])
    dut.n3_y.value = to_q16_16(nazi_points[2][1])
    dut.n4_x.value = to_q16_16(nazi_points[3][0])
    dut.n4_y.value = to_q16_16(nazi_points[3][1])
    
    dut.c1_x.value = to_q16_16(castle_points[0][0])
    dut.c1_y.value = to_q16_16(castle_points[0][1])
    dut.c2_x.value = to_q16_16(castle_points[1][0])
    dut.c2_y.value = to_q16_16(castle_points[1][1])
    dut.c3_x.value = to_q16_16(castle_points[2][0])
    dut.c3_y.value = to_q16_16(castle_points[2][1])
    dut.c4_x.value = to_q16_16(castle_points[3][0])
    dut.c4_y.value = to_q16_16(castle_points[3][1])
    
    await Timer(10, units='ns')
    
    result = int(dut.danger.value)
    print(f"Result: {result:04b}, Expected: {expected_danger:04b}")
    assert result == expected_danger, f"Expected {expected_danger:04b}, got {result:04b}"

@cocotb.test()
async def test_castle_danger_all_outside(dut):
    """Test case where all castles are outside"""
    
    # Nazi: (1,1), (3,1), (3,3), (1,3) - small square
    # All castles far away
    
    nazi_points = [(1,1), (3,1), (3,3), (1,3)]
    castle_points = [(10,10), (20,20), (5,15), (15,5)]
    expected_danger = 0b0000  # None in danger
    
    dut.n1_x.value = to_q16_16(nazi_points[0][0])
    dut.n1_y.value = to_q16_16(nazi_points[0][1])
    dut.n2_x.value = to_q16_16(nazi_points[1][0])
    dut.n2_y.value = to_q16_16(nazi_points[1][1])
    dut.n3_x.value = to_q16_16(nazi_points[2][0])
    dut.n3_y.value = to_q16_16(nazi_points[2][1])
    dut.n4_x.value = to_q16_16(nazi_points[3][0])
    dut.n4_y.value = to_q16_16(nazi_points[3][1])
    
    dut.c1_x.value = to_q16_16(castle_points[0][0])
    dut.c1_y.value = to_q16_16(castle_points[0][1])
    dut.c2_x.value = to_q16_16(castle_points[1][0])
    dut.c2_y.value = to_q16_16(castle_points[1][1])
    dut.c3_x.value = to_q16_16(castle_points[2][0])
    dut.c3_y.value = to_q16_16(castle_points[2][1])
    dut.c4_x.value = to_q16_16(castle_points[3][0])
    dut.c4_y.value = to_q16_16(castle_points[3][1])
    
    await Timer(10, units='ns')
    
    result = int(dut.danger.value)
    print(f"Result: {result:04b}, Expected: {expected_danger:04b}")
    assert result == expected_danger, f"Expected {expected_danger:04b}, got {result:04b}"

@cocotb.test()
async def test_castle_danger_all_inside(dut):
    """Test case where all castles are inside"""
    
    # Nazi: (0,0), (10,0), (10,10), (0,10) - large square
    # All castles inside
    
    nazi_points = [(0,0), (10,0), (10,10), (0,10)]
    castle_points = [(2,2), (5,5), (8,8), (3,7)]
    expected_danger = 0b1111  # All inside
    
    dut.n1_x.value = to_q16_16(nazi_points[0][0])
    dut.n1_y.value = to_q16_16(nazi_points[0][1])
    dut.n2_x.value = to_q16_16(nazi_points[1][0])
    dut.n2_y.value = to_q16_16(nazi_points[1][1])
    dut.n3_x.value = to_q16_16(nazi_points[2][0])
    dut.n3_y.value = to_q16_16(nazi_points[2][1])
    dut.n4_x.value = to_q16_16(nazi_points[3][0])
    dut.n4_y.value = to_q16_16(nazi_points[3][1])
    
    dut.c1_x.value = to_q16_16(castle_points[0][0])
    dut.c1_y.value = to_q16_16(castle_points[0][1])
    dut.c2_x.value = to_q16_16(castle_points[1][0])
    dut.c2_y.value = to_q16_16(castle_points[1][1])
    dut.c3_x.value = to_q16_16(castle_points[2][0])
    dut.c3_y.value = to_q16_16(castle_points[2][1])
    dut.c4_x.value = to_q16_16(castle_points[3][0])
    dut.c4_y.value = to_q16_16(castle_points[3][1])
    
    await Timer(10, units='ns')
    
    result = int(dut.danger.value)
    print(f"Result: {result:04b}, Expected: {expected_danger:04b}")
    assert result == expected_danger, f"Expected {expected_danger:04b}, got {result:04b}"

print("Running castle_danger_checker tests...")
print("Expected output: All tests should pass with 7/7 or 8/8 depending on implementation")