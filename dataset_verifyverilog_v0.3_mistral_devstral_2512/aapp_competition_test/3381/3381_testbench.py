import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_N = 16
MAX_COORD = (1 << DATA_WIDTH) - 1  # 255

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY READ HELPER
# ============================================================================

def read_points(dut, n):
    """Read points from the DUT for indices 0 to n-1."""
    points = []
    for i in range(n):
        x_sig = getattr(dut, f'x_{i}')
        y_sig = getattr(dut, f'y_{i}')
        if is_value_defined(x_sig.value) and is_value_defined(y_sig.value):
            x = int(x_sig.value)
            y = int(y_sig.value)
            points.append((x, y))
        else:
            raise TestFailure(f"Undefined value at point {i}")
    return points

# ============================================================================
# CONVEXITY AND COLLINEARITY CHECK
# ============================================================================

def check_convexity(points):
    """Check if points are in convex position with no three collinear."""
    n = len(points)
    if n < 3:
        return True
    
    # Check distinctness
    if len(set(points)) != n:
        return False
    
    # Check for three collinear points
    for i in range(n):
        for j in range(i+1, n):
            for k in range(j+1, n):
                x1, y1 = points[i]
                x2, y2 = points[j]
                x3, y3 = points[k]
                # Cross product to check collinearity
                cross = (x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1)
                if cross == 0:
                    return False
    
    # Check convexity: all turns should be in same direction (e.g., all counterclockwise)
    # For small N, we can check by computing cross products of consecutive edges
    # Sort points by x then y to get them in order
    sorted_points = sorted(points)
    # Compute cross products for consecutive triples
    signs = []
    for i in range(n):
        p1 = sorted_points[i]
        p2 = sorted_points[(i+1) % n]
        p3 = sorted_points[(i+2) % n]
        cross = (p2[0] - p1[0]) * (p3[1] - p1[1]) - (p2[1] - p1[1]) * (p3[0] - p1[0])
        if cross == 0:
            return False
        signs.append(cross > 0)
    # All signs should be the same (either all positive or all negative)
    if not all(signs) and any(signs):
        return False
    
    return True

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_convex_polygon_gen(dut):
    """Test the convex polygon generator for various N values."""
    
    # Test N from 3 to 16 (cover edge cases)
    test_values = [3, 4, 5, 8, 12, 16]
    
    passed = 0
    failed = 0
    
    for n in test_values:
        cocotb.log.info(f"Testing N={n}")
        
        # Set N
        dut.N.value = n
        
        # Wait for combinational logic to settle
        await Timer(100, units='ns')
        
        try:
            # Read points
            points = read_points(dut, n)
            
            # Verify coordinates are within bounds
            for i, (x, y) in enumerate(points):
                if x > MAX_COORD or y > MAX_COORD:
                    raise TestFailure(f"Point {i} out of bounds: ({x},{y})")
            
            # Verify points match expected triangular numbers sequence
            for i in range(n):
                expected_x = i
                expected_y = i * (i - 1) // 2
                actual_x, actual_y = points[i]
                if actual_x != expected_x or actual_y != expected_y:
                    raise TestFailure(
                        f"Point {i}: expected ({expected_x},{expected_y}), got ({actual_x},{actual_y})"
                    )
            
            # Verify convexity and no three collinear
            if not check_convexity(points):
                raise TestFailure("Points are not in convex position or have collinear triples")
            
            cocotb.log.info(f"  PASS: {n} points generated correctly")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} test groups passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test groups failed")
