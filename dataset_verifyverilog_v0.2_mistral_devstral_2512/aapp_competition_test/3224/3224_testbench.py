import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import math

# Helper function to convert float to Q16.16 fixed-point
def to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# Helper function to convert Q16.16 to float
def from_q16_16(value):
    if value & 0x80000000:  # Negative number
        return -((~value + 1) / 65536.0)
    else:
        return value / 65536.0

def compute_circumsphere(p1, p2, p3, p4):
    """Compute circumsphere center for 4 points"""
    # Using linear algebra approach
    # Form system: 2(xj-xi)x + 2(yj-yi)y + 2(zj-zi)z = xj²-xi² + yj²-yi² + zj²-zi²
    
    xi, yi, zi = p1
    
    # Point 2
    xj, yj, zj = p2
    a11 = 2*(xj - xi)
    a12 = 2*(yj - yi)
    a13 = 2*(zj - zi)
    b1 = xj**2 - xi**2 + yj**2 - yi**2 + zj**2 - zi**2
    
    # Point 3
    xj, yj, zj = p3
    a21 = 2*(xj - xi)
    a22 = 2*(yj - yi)
    a23 = 2*(zj - zi)
    b2 = xj**2 - xi**2 + yj**2 - yi**2 + zj**2 - zi**2
    
    # Point 4
    xj, yj, zj = p4
    a31 = 2*(xj - xi)
    a32 = 2*(yj - yi)
    a33 = 2*(zj - zi)
    b3 = xj**2 - xi**2 + yj**2 - yi**2 + zj**2 - zi**2
    
    # Determinant of A
    detA = a11*(a22*a33 - a23*a32) - a12*(a21*a33 - a23*a31) + a13*(a21*a32 - a22*a31)
    
    # Determinants for x, y, z
    detX = b1*(a22*a33 - a23*a32) - a12*(b2*a33 - b2*a32) + a13*(b2*a32 - a22*b3)
    detX = b1*(a22*a33 - a23*a32) - a12*(b2*a33 - b2*a32) + a13*(b2*a32 - a22*b3)
    
    # Corrected X determinant
    detX = b1*(a22*a33 - a23*a32) - a12*(b2*a33 - b3*a23) + a13*(b2*a32 - b3*a22)
    
    # Y determinant  
    detY = a11*(b2*a33 - b3*a23) - b1*(a21*a33 - a31*a23) + a13*(a21*b3 - a31*b2)
    
    # Z determinant
    detZ = a11*(a22*b3 - a32*b2) - a12*(a21*b3 - a31*b2) + b1*(a21*a32 - a31*a22)
    
    if abs(detA) < 1e-9:
        return (0.0, 0.0, 0.0)
    
    cx = detX / detA
    cy = detY / detA
    cz = detZ / detA
    
    return (cx, cy, cz)

@cocotb.test()
async def test_circumsphere(dut):
    """Test circumsphere center calculation"""
    
    # Test case 1: (0,0,0), (1,0,0), (0,1,0), (0,0,1)
    # Expected: (0.5, 0.5, 0.5)
    dut.p1_x.value = 0
    dut.p1_y.value = 0
    dut.p1_z.value = 0
    dut.p2_x.value = 1
    dut.p2_y.value = 0
    dut.p2_z.value = 0
    dut.p3_x.value = 0
    dut.p3_y.value = 1
    dut.p3_z.value = 0
    dut.p4_x.value = 0
    dut.p4_y.value = 0
    dut.p4_z.value = 1
    
    await Timer(10, units='ns')
    
    result_x = from_q16_16(int(dut.center_x.value))
    result_y = from_q16_16(int(dut.center_y.value))
    result_z = from_q16_16(int(dut.center_z.value))
    
    print(f"Test 1 - Got: ({result_x:.6f}, {result_y:.6f}, {result_z:.6f})")
    print(f"         Expected: (0.5, 0.5, 0.5)")
    
    assert abs(result_x - 0.5) < 0.01, f"X mismatch: {result_x} vs 0.5"
    assert abs(result_y - 0.5) < 0.01, f"Y mismatch: {result_y} vs 0.5"
    assert abs(result_z - 0.5) < 0.01, f"Z mismatch: {result_z} vs 0.5"
    
    # Test case 2: (-1,0,0), (1,0,0), (0,1,0), (0,0,1)
    # Expected: (0.0, 0.0, 0.0)
    dut.p1_x.value = -1
    dut.p1_y.value = 0
    dut.p1_z.value = 0
    dut.p2_x.value = 1
    dut.p2_y.value = 0
    dut.p2_z.value = 0
    dut.p3_x.value = 0
    dut.p3_y.value = 1
    dut.p3_z.value = 0
    dut.p4_x.value = 0
    dut.p4_y.value = 0
    dut.p4_z.value = 1
    
    await Timer(10, units='ns')
    
    result_x = from_q16_16(int(dut.center_x.value))
    result_y = from_q16_16(int(dut.center_y.value))
    result_z = from_q16_16(int(dut.center_z.value))
    
    print(f"Test 2 - Got: ({result_x:.6f}, {result_y:.6f}, {result_z:.6f})")
    print(f"         Expected: (0.0, 0.0, 0.0)")
    
    assert abs(result_x) < 0.01, f"X mismatch: {result_x} vs 0.0"
    assert abs(result_y) < 0.01, f"Y mismatch: {result_y} vs 0.0"
    assert abs(result_z) < 0.01, f"Z mismatch: {result_z} vs 0.0"
    
    # Test case 3: (0,0,0), (7,0,0), (0,6,0), (1,-2,-3)
    # Expected: (3.5, 3.0, -3.16666667)
    dut.p1_x.value = 0
    dut.p1_y.value = 0
    dut.p1_z.value = 0
    dut.p2_x.value = 7
    dut.p2_y.value = 0
    dut.p2_z.value = 0
    dut.p3_x.value = 0
    dut.p3_y.value = 6
    dut.p3_z.value = 0
    dut.p4_x.value = 1
    dut.p4_y.value = -2
    dut.p4_z.value = -3
    
    await Timer(10, units='ns')
    
    result_x = from_q16_16(int(dut.center_x.value))
    result_y = from_q16_16(int(dut.center_y.value))
    result_z = from_q16_16(int(dut.center_z.value))
    
    print(f"Test 3 - Got: ({result_x:.6f}, {result_y:.6f}, {result_z:.6f})")
    print(f"         Expected: (3.5, 3.0, -3.166667)")
    
    assert abs(result_x - 3.5) < 0.01, f"X mismatch: {result_x} vs 3.5"
    assert abs(result_y - 3.0) < 0.01, f"Y mismatch: {result_y} vs 3.0"
    assert abs(result_z - (-3.166667)) < 0.01, f"Z mismatch: {result_z} vs -3.166667"
    
    # Test case 4: Edge case with negative coordinates
    dut.p1_x.value = -10
    dut.p1_y.value = -10
    dut.p1_z.value = -10
    dut.p2_x.value = 10
    dut.p2_y.value = -10
    dut.p2_z.value = -10
    dut.p3_x.value = -10
    dut.p3_y.value = 10
    dut.p3_z.value = -10
    dut.p4_x.value = -10
    dut.p4_y.value = -10
    dut.p4_z.value = 10
    
    await Timer(10, units='ns')
    
    result_x = from_q16_16(int(dut.center_x.value))
    result_y = from_q16_16(int(dut.center_y.value))
    result_z = from_q16_16(int(dut.center_z.value))
    
    print(f"Test 4 - Got: ({result_x:.6f}, {result_y:.6f}, {result_z:.6f})")
    print(f"         Expected: (0.0, 0.0, 0.0)")
    
    assert abs(result_x) < 0.01, f"X mismatch: {result_x} vs 0.0"
    assert abs(result_y) < 0.01, f"Y mismatch: {result_y} vs 0.0"
    assert abs(result_z) < 0.01, f"Z mismatch: {result_z} vs 0.0"
    
    # Test case 5: Asymmetric points
    dut.p1_x.value = 1
    dut.p1_y.value = 2
    dut.p1_z.value = 3
    dut.p2_x.value = 4
    dut.p2_y.value = 5
    dut.p2_z.value = 6
    dut.p3_x.value = 7
    dut.p3_y.value = 8
    dut.p3_z.value = 9
    dut.p4_x.value = 10
    dut.p4_y.value = 11
    dut.p4_z.value = 12
    
    await Timer(10, units='ns')
    
    result_x = from_q16_16(int(dut.center_x.value))
    result_y = from_q16_16(int(dut.center_y.value))
    result_z = from_q16_16(int(dut.center_z.value))
    
    expected = compute_circumsphere((1,2,3), (4,5,6), (7,8,9), (10,11,12))
    print(f"Test 5 - Got: ({result_x:.6f}, {result_y:.6f}, {result_z:.6f})")
    print(f"         Expected: ({expected[0]:.6f}, {expected[1]:.6f}, {expected[2]:.6f})")
    
    assert abs(result_x - expected[0]) < 0.01, f"X mismatch: {result_x} vs {expected[0]}"
    assert abs(result_y - expected[1]) < 0.01, f"Y mismatch: {result_y} vs {expected[1]}"
    assert abs(result_z - expected[2]) < 0.01, f"Z mismatch: {result_z} vs {expected[2]}"
    
    print("
5/5 tests passed!")