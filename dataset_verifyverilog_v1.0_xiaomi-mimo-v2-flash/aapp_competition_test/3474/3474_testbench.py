import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def float_to_q8_8(f):
    """Convert float to Q8.8 fixed point (16-bit signed)"""
    val = int(f * 256)
    # Clamp to 16-bit signed range
    if val > 32767: val = 32767
    if val < -32768: val = -32768
    return from_signed(val, 16) if val < 0 else val

def q8_8_to_float(v):
    """Convert Q8.8 to float (assuming 16-bit input)"""
    signed_val = to_signed(v, 16)
    return signed_val / 256.0

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Python reference implementation for validation
def calculate_reflection(x1, y1, x2, y2, sx, sy):
    """Returns (hit, y_min, y_max) where hit is bool, y in float"""
    # Mirror line: Ax + By + C = 0
    A = y1 - y2
    B = x2 - x1
    C = x1*y2 - x2*y1
    
    # Check if mirror is valid (not a point)
    if A == 0 and B == 0:
        return False, 0, 0
    
    # Reflect shooter across mirror line
    # Formula: vx = sx - 2*A*(A*sx + B*sy + C) / (A*A + B*B)
    denom = A*A + B*B
    if denom == 0:
        return False, 0, 0
    
    num = A*sx + B*sy + C
    vx = sx - 2*A*num / denom
    vy = sy - 2*B*num / denom
    
    # Line from virtual point (vx, vy) to wall at x=0
    # Parametric: (vx*t, vy*t) where t goes from 0 to 1
    # We need point where x=0: vx*t = 0 => t = 0 (if vx != 0)
    # Wait, need line from virtual to shooter? No, reflection law.
    # Correct: Line from virtual point to wall direction is from virtual to shooter?
    # Actually, law of reflection: angle of incidence = angle of reflection
    # For flat mirror: reflected ray goes from mirror point to virtual point
    # But we need intersection with wall. 
    
    # Simplified: For flat mirror, we can compute where the reflected ray hits x=0
    # Ray direction from mirror point to virtual point
    # But we don't know mirror point. Alternative approach:
    # Find intersection of line from shooter to mirror, then reflect to wall.
    
    # Standard approach for laser tag with flat mirror:
    # 1. Find all possible reflection points on mirror segment
    # 2. For each, compute where reflected ray hits x=0
    # This is complex for hardware. Simplified:
    # Check if virtual point sees the wall through mirror segment.
    
    # Let's use the method: 
    # If shooter at (sx, sy), mirror segment M1-M2, wall at x=0
    # Compute reflected ray direction for each endpoint
    # This is too complex for bounded hardware. 
    
    # Practical hardware solution:
    # 1. Check if shooter and wall are on same side of mirror line
    #    If yes, can't hit wall (laser goes away from wall)
    # 2. Compute intersection of line (shooter->wall) with mirror line
    # 3. Check if intersection point is on mirror segment
    # 4. If yes, compute reflection and find new wall intersection
    
    # Evaluate shooter and wall side
    def side(x, y):
        return A*x + B*y + C
    
    side_shooter = side(sx, sy)
    side_wall = side(0, 0)  # Assuming wall at x=0 passes through origin for side check
    # Actually wall is infinite line x=0, but we need to check if reflection possible
    
    # For flat mirror, laser can hit wall if shooter and wall are on opposite sides
    # OR if mirror can redirect ray that would miss wall
    # This is getting too complex for hardware scaling.
    
    # Simplified algorithm for 8-16 node scaling:
    # Assume mirror is small segment. Compute reflection for endpoints only.
    # If both endpoints give valid wall intersections, take range.
    # If none, can't hit.
    
    # Compute reflection point for endpoint 1
    # Line from shooter to endpoint
    dx = x1 - sx
    dy = y1 - sy
    
    # Check if line to endpoint is valid (doesn't cross mirror backwards)
    # Then compute reflected direction
    # For flat mirror at endpoint, normal is perpendicular to mirror
    
    # This is still complex. Let's implement a bounded version:
    # For hardware, we'll compute the line from shooter to wall that reflects off mirror.
    # Use the fact that reflected path from shooter to wall via mirror
    # is equivalent to straight line from shooter to virtual wall.
    
    # Virtual wall is reflection of wall across mirror.
    # Wall at x=0, mirror line Ax+By+C=0.
    # Reflect wall to virtual wall.
    # Then line from shooter to virtual wall intersects real wall at target.
    
    # Reflect wall line x=0 across mirror:
    # For point (0, y) on wall, its reflection across mirror line:
    # vx = 0 - 2*A*(A*0 + B*y + C) / (A*A + B*B)
    # vy = y - 2*B*(A*0 + B*y + C) / (A*A + B*B)
    # This gives a line of virtual wall points.
    
    # The virtual wall is also a line. Its equation can be computed.
    # Then line from shooter (sx, sy) to any point on virtual wall
    # intersects real wall at some y.
    
    # This is too much for hardware. Let's use a simplified bounded approach:
    # Assume we only need to handle cases where reflection is possible.
    # Compute the range of y where the reflected ray hits wall.
    
    # For the given problem constraints (scaled to 8-16 bits):
    # We'll implement the endpoint-based method.
    
    # Calculate for endpoint 1
    # Line from shooter to endpoint
    dx1 = x1 - sx
    dy1 = y1 - sy
    
    # If dx1 is 0 (vertical), special case
    if abs(dx1) < 0.0001:
        # Vertical line, check if can hit wall
        # For flat mirror, vertical line reflection
        # Simplified: if shooter x != mirror x, and mirror is vertical
        if abs(B) > 0.0001:  # Mirror not vertical
            return False, 0, 0
        # Mirror is vertical
        # Reflection: x flips, y stays
        # Line from (sx, sy) to (x1, y1) to wall
        # For vertical mirror, reflected ray goes to (x1 - (sx - x1), sy) = (2*x1 - sx, sy)
        # Then line from (x1, y1) to (2*x1 - sx, sy) hits wall at x=0
        if abs(2*x1 - sx) < 0.0001:
            return False, 0, 0
        t = -x1 / (2*x1 - sx - x1)  # Parametric: x = x1 + t*(2*x1 - sx - x1) = 0
        # Actually simpler: line from (x1, y1) to (2*x1 - sx, sy)
        # Slope m = (sy - y1) / (2*x1 - sx - x1) = (sy - y1) / (x1 - sx)
        # y = y1 + m*(0 - x1) = y1 - (sy - y1) * x1 / (x1 - sx)
        y_wall = y1 - (sy - y1) * x1 / (x1 - sx)
        # Check if this reflection point is on mirror segment
        # Since mirror is vertical, check if y_wall between y1 and y2
        # But we need to check if the reflection point on mirror is valid
        # Actually for vertical mirror, any point on mirror works if laser hits mirror
        # The issue is whether laser from shooter hits the mirror segment first
        
        # Check if line from shooter to wall intersects mirror segment
        # Line from (sx, sy) to (0, y_wall)
        # Intersection with vertical line x=x1
        if sx == 0: return False, 0, 0
        t_int = (x1 - sx) / (0 - sx)
        y_int = sy + t_int * (y_wall - sy)
        # Check if y_int is between y1 and y2
        if min(y1, y2) - 0.0001 <= y_int <= max(y1, y2) + 0.0001:
            return True, y_wall, y_wall
        else:
            return False, 0, 0
    
    # General case (non-vertical mirror)
    # Compute intersection of line (shooter->wall at x=0) with mirror line
    # Line from (sx, sy) to (0, yt) where yt is unknown
    # Parametric: x = sx + t*(0 - sx) = sx*(1-t), y = sy + t*(yt - sy)
    # At intersection with mirror: A*x + B*y + C = 0
    # This gives equation for yt. Then check if intersection point is on segment.
    
    # For given yt, intersection point is where line hits mirror.
    # But we need to find yt such that reflected ray goes to wall.
    # This is circular. 
    
    # Correct approach for flat mirror:
    # 1. Find virtual point V by reflecting shooter across mirror line.
    # 2. For any point P on mirror, reflected ray goes from P to V.
    # 3. This ray will hit wall at some y.
    # 4. We need the ray from P on mirror to V to hit wall.
    # 5. As P moves along mirror, y changes.
    # 6. Find min and max y when P is at endpoints.
    
    # Compute virtual point V
    denom = A*A + B*B
    if denom == 0:
        return False, 0, 0
    
    num = A*sx + B*sy + C
    vx = sx - 2*A*num / denom
    vy = sy - 2*B*num / denom
    
    # Now for each endpoint P of mirror, compute line P->V intersection with wall x=0
    results = []
    for (px, py) in [(x1, y1), (x2, y2)]:
        # Line from (px, py) to (vx, vy)
        # Parametric: x = px + t*(vx - px), y = py + t*(vy - py)
        # Set x=0: t = -px / (vx - px) if vx != px
        if abs(vx - px) < 0.0001:
            # Vertical line, parallel to wall
            if abs(px) < 0.0001:
                # On wall, infinite
                return True, float('-inf'), float('inf')
            continue  # No intersection
        t = -px / (vx - px)
        y_wall = py + t * (vy - py)
        # Check if t is between 0 and 1 (ray from mirror to V goes forward)
        # Actually for reflection, we consider ray from mirror to V, which is backward from V to mirror.
        # But geometrically, the line extends both ways.
        # We need to ensure the reflection point on mirror is valid.
        # For endpoint P, the ray from P to V corresponds to reflection at P.
        # This is valid if P is on the mirror segment.
        results.append(y_wall)
    
    if not results:
        return False, 0, 0
    
    # Also need to check if the entire segment reflects to a continuous range
    # For flat mirror, the range of wall hits is between the two endpoint calculations
    # if the mirror is convex to the wall.
    
    # Simplified: take min and max of results
    y_min = min(results)
    y_max = max(results)
    
    # Additional check: is the mirror facing the shooter?
    # If both endpoints give same infinity, might be infinite range
    if abs(y_min) > 1e10 or abs(y_max) > 1e10:
        # Handle infinity
        return True, y_min, y_max
    
    # Check if mirror is visible from shooter for any point
    # This is complex. For hardware, we'll assume if we get finite values, it's valid.
    # But need to verify if there exists a point on mirror that reflects to wall.
    # This requires checking if the virtual point V and wall are on opposite sides of mirror.
    
    # Check side of V and wall relative to mirror line
    side_V = A*vx + B*vy + C
    side_wall = A*0 + B*0 + C  # Point (0,0) on wall line
    
    if side_V * side_wall >= 0:  # Same side or on line
        return False, 0, 0
    
    # Also need to check if the reflection point on mirror is between endpoints
    # For flat mirror, if V and wall are on opposite sides, the ray V->wall will intersect mirror
    # somewhere. Need to check if that intersection is on segment.
    
    # Find intersection of line V->wall (x=0) with mirror line
    # Line from V to (0, yt) where yt is unknown
    # But we can compute intersection of line V->wall with mirror line
    # Parameterize line V->wall: x = vx + t*(0 - vx) = vx*(1-t)
    # y = vy + t*(yt - vy)  (yt is the wall hit point, unknown)
    # Instead, find intersection of line V->wall with mirror line.
    # But we don't know wall hit point. 
    
    # Alternative: Find intersection of line V->wall with mirror line directly.
    # The line from V to any point on wall is x = vx*(1-t), y = vy + t*(y_wall - vy)
    # We need this line to intersect mirror line at some t.
    # This is getting too mathematical for bounded hardware.
    
    # For the competition problem, the expected solution is:
    # 1. Compute virtual point V.
    # 2. For each endpoint of mirror, compute where line from endpoint to V hits wall.
    # 3. If both endpoints produce valid intersections, the range is between them.
    # 4. If only one endpoint is valid, it's a point.
    # 5. If mirror is infinite (in practice, if V and wall are aligned such that all reflections hit),
    #    output infinity.
    
    # In the examples:
    # Example 1: Mirror (5,10)-(10,10), Shooter (10,0)
    # Mirror horizontal, shooter below. Virtual point is (10,20) [reflected across y=10]
    # Line from (5,10) to (10,20): slope 2, hits x=0 at y = 10 - 2*5 = 0
    # Line from (10,10) to (10,20): vertical, no hit -> but wait, example says negative-infinity 0
    # Actually, for horizontal mirror, the reflected rays cover all y <= 0.
    
    # Let's re-examine example 1:
    # Mirror from x=5 to x=10 at y=10, shooter at (10,0).
    # Virtual point is (10,20).
    # For any point P=(x,10) on mirror, line from P to V is (x,10)->(10,20).
    # This line hits x=0 at y = 10 - 20*(x-0)/(10-x) ?
    # Parametric: x' = x + t*(10-x), y' = 10 + t*(20-10) = 10 + 10t
    # Set x'=0: t = -x/(10-x)
    # y' = 10 + 10*(-x/(10-x)) = 10*(1 - x/(10-x)) = 10*((10-x - x)/(10-x)) = 10*(10-2x)/(10-x)
    # As x goes from 5 to 10, y' goes from 10*(10-10)/(5) = 0 to -infinity (as x->10)
    # So range is (-inf, 0].
    
    # So for hardware, we need to compute the range by evaluating endpoints.
    # For endpoint (5,10): y_wall = 0
    # For endpoint (10,10): line is vertical, hits wall at infinity.
    
    # So algorithm:
    # 1. Compute V
    # 2. For each endpoint P, compute line P->V intersection with x=0.
    #    If vertical (vx == px), then if px != 0, it's parallel, no hit (or infinite if px=0).
    #    Actually, if vx == px, line is vertical x=px. If px==0, it's on wall, infinite.
    #    If px != 0, no intersection.
    # 3. Collect valid y values.
    # 4. If both endpoints give finite values, output min, max.
    # 5. If one endpoint gives finite, other infinite, output negative-infinity or positive-infinity.
    # 6. If both infinite, output can't hit (or both infinities).
    
    # Also need to check if the mirror is oriented such that the reflection is possible.
    # Check if V and wall are on opposite sides of mirror line.
    
    # Let's code this logic
    
    # Re-calculate with proper side check
    side_V = A*vx + B*vy + C
    side_origin = A*0 + B*0 + C
    
    if side_V * side_origin >= 0:
        return False, 0, 0
    
    # Now compute for endpoints
    y_vals = []
    is_infinite = [False, False]
    
    for i, (px, py) in enumerate([(x1, y1), (x2, y2)]):
        if abs(vx - px) < 0.0001:
            # Vertical line
            if abs(px) < 0.0001:
                # On wall, infinite range
                is_infinite[i] = True
                y_vals.append(0)  # Placeholder
            else:
                # No intersection, but might still be valid if mirror can hit
                # For vertical mirror, we need to handle separately
                # If mirror is vertical, B=0, A!=0
                if abs(B) < 0.0001:  # Vertical mirror
                    # Reflection from vertical mirror
                    # Virtual point vx = 2*x1 - sx (since mirror at x=x1)
                    # Actually V is computed correctly
                    # For endpoint P on vertical mirror, line P->V is vertical if V has same x
                    # But V x = sx - 2*A*(A*sx+B*sy+C)/(A*A)  (B=0)
                    # A = y1-y2, C = x1*y2 - x2*y1 = x1*(y2-y1) = -x1*A
                    # num = A*sx + C = A*(sx - x1)
                    # vx = sx - 2*A*A*(sx-x1)/(A*A) = sx - 2*(sx-x1) = 2*x1 - sx
                    # So vx = 2*x1 - sx
                    # Since mirror vertical at x=x1, vx = 2*x1 - sx != sx unless x1=sx
                    # So vx != px for endpoint px=x1
                    # Wait, px = x1, vx = 2*x1 - sx. So vx - px = x1 - sx
                    # This is not zero unless sx=x1 (shooter on mirror, not allowed)
                    # So vertical case only if sx=x1, which is disallowed.
                    pass
                continue
        
        t = -px / (vx - px)
        y_wall = py + t * (vy - py)
        
        # Check if t is between 0 and 1 for the ray from mirror to V
        # But for reflection, we consider the ray from mirror to V, which is the reflected ray.
        # The parameter t should be between 0 and 1 for the segment from mirror to V.
        # However, we care about the ray extending beyond V to the wall.
        # Actually, the ray from mirror to V continues beyond V.
        # So t can be any positive number.
        # But we need the reflection point to be on the mirror, which it is (at t=0).
        
        y_vals.append(y_wall)
    
    # Now determine output
    if len(y_vals) == 0:
        return False, 0, 0
    
    # Check for infinity
    inf_pos = False
    inf_neg = False
    finite_vals = []
    
    for i, y in enumerate(y_vals):
        if is_infinite[i] or abs(y) > 1e10:
            # Determine direction of infinity
            # Check slope from mirror endpoint to V
            px, py = [(x1, y1), (x2, y2)][i]
            if abs(vx - px) < 0.0001:
                # Vertical line, if px > 0, goes to negative infinity (if vy > py) or positive infinity
                # Actually depends on direction
                # For example, if V is above mirror, vertical line goes up, so +inf if wall is to left
                if vy > py:
                    inf_pos = True
                else:
                    inf_neg = True
            else:
                # Check limit as t -> infinity
                # y_wall = py + t*(vy - py) / (vx - px) * (-px) ... no
                # Actually y_wall = py + (-px/(vx-px)) * (vy-py)
                # This is finite. The infinity comes from the vertical line case.
                pass
        else:
            finite_vals.append(y)
    
    # For the examples, the infinity comes from vertical line case
    # Example 1: endpoint (10,10), vx=10, so vertical line, px=10!=0, but ray goes to infinity
    # Actually in example 1, for endpoint (10,10), vx=10, so line is vertical x=10.
    # This line never hits wall at x=0, so why infinity?
    # Because the reflected ray from points near (10,10) on the mirror hits wall at large negative y.
    # As the point approaches (10,10), y_wall -> -infinity.
    
    # So for endpoint calculations, if the line is parallel to wall (vertical), it's infinite.
    # But only if the mirror extends to that endpoint.
    
    # Revised: If for an endpoint, vx == px and px != 0, then the reflected ray is parallel to wall.
    # This means as we approach that endpoint, y_wall -> +/- infinity.
    
    # So in code:
    y_min = float('inf')
    y_max = float('-inf')
    hit = False
    
    for i, (px, py) in enumerate([(x1, y1), (x2, y2)]):
        if abs(vx - px) < 0.0001:
            # Parallel to wall
            if abs(px) < 0.0001:
                # On wall, infinite
                hit = True
                # Need to determine infinity direction
                if vy >= py:
                    inf_pos = True
                else:
                    inf_neg = True
            else:
                # Parallel but not on wall -> as we approach, infinity
                hit = True
                if vy > py:
                    inf_pos = True
                else:
                    inf_neg = True
        else:
            t = -px / (vx - px)
            y_wall = py + t * (vy - py)
            hit = True
            y_min = min(y_min, y_wall)
            y_max = max(y_max, y_wall)
    
    if not hit:
        return False, 0, 0
    
    # If both infinities, it's the whole line
    if inf_pos and inf_neg:
        return True, float('-inf'), float('inf')
    if inf_pos:
        if y_min == float('inf'):
            return True, float('-inf'), float('inf')  # Should not happen
        return True, y_min, float('inf')
    if inf_neg:
        if y_max == float('-inf'):
            return True, float('-inf'), float('inf')
        return True, float('-inf'), y_max
    
    return True, y_min, y_max

# Test cases from example
test_cases = [
    ([5, 10, 10, 10, 10, 0], True, 0, 0),  # Example 1: negative-infinity 0
    ([5, 10, 10, 5, 10, 0], True, 5, 12.5),  # Example 2: 5 12.5
    ([6, 10, 10, 10, 10, 0], True, -5, -5),  # Example 3: negative-infinity -5
    ([10, 10, 20, 20, 20, 10], False, 0, 0),  # Can't hit
]

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_laser_reflection(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, (inputs, exp_hit, exp_y1, exp_y2) in enumerate(test_cases):
        x1, y1, x2, y2, sx, sy = inputs
        cocotb.log.info(f"Test {i+1}: Mirror ({x1},{y1})-({x2},{y2}), Shooter ({sx},{sy})")
        
        try:
            # Convert to Q8.8
            dut.x1.value = float_to_q8_8(x1)
            dut.y1.value = float_to_q8_8(y1)
            dut.x2.value = float_to_q8_8(x2)
            dut.y2.value = float_to_q8_8(y2)
            dut.sx.value = float_to_q8_8(sx)
            dut.sy.value = float_to_q8_8(sy)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            hit_val = int(dut.hit.value) if has_signal(dut, 'hit') else 0
            y_min_val = int(dut.y_min.value) if has_signal(dut, 'y_min') else 0
            y_max_val = int(dut.y_max.value) if has_signal(dut, 'y_max') else 0
            
            # Convert back to float
            hit = (hit_val == 1)
            y_min = q8_8_to_float(y_min_val)
            y_max = q8_8_to_float(y_max_val)
            
            # Handle infinity in output
            INF = 1e10
            if abs(y_min) > INF or y_min < -INF:
                y_min = float('-inf')
            if abs(y_max) > INF or y_max > INF:
                y_max = float('inf')
            
            # Python reference
            py_hit, py_y1, py_y2 = calculate_reflection(x1, y1, x2, y2, sx, sy)
            
            # Compare
            if hit != py_hit:
                raise TestFailure(f"Hit mismatch: expected {py_hit}, got {hit}")
            
            if py_hit:
                # Check if infinity matches
                if (abs(y_min) > 1e9) != (abs(py_y1) > 1e9):
                    raise TestFailure(f"Infinity mismatch for y_min: {y_min} vs {py_y1}")
                if (abs(y_max) > 1e9) != (abs(py_y2) > 1e9):
                    raise TestFailure(f"Infinity mismatch for y_max: {y_max} vs {py_y2}")
                
                if abs(y_min) < 1e9 and abs(py_y1) < 1e9:
                    if abs(y_min - py_y1) > 0.01:
                        raise TestFailure(f"y_min mismatch: {y_min} vs {py_y1}")
                if abs(y_max) < 1e9 and abs(py_y2) < 1e9:
                    if abs(y_max - py_y2) > 0.01:
                        raise TestFailure(f"y_max mismatch: {y_max} vs {py_y2}")
            
            passed += 1
            cocotb.log.info(f"  Result: hit={hit}, y_min={y_min}, y_max={y_max}")
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")

# Additional test for infinity cases
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_infinity(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test case: horizontal mirror, shooter below -> negative-infinity to some y
    x1, y1, x2, y2, sx, sy = 5, 10, 10, 10, 10, 0
    
    dut.x1.value = float_to_q8_8(x1)
    dut.y1.value = float_to_q8_8(y1)
    dut.x2.value = float_to_q8_8(x2)
    dut.y2.value = float_to_q8_8(y2)
    dut.sx.value = float_to_q8_8(sx)
    dut.sy.value = float_to_q8_8(sy)
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')
    
    hit_val = int(dut.hit.value) if has_signal(dut, 'hit') else 0
    y_min_val = int(dut.y_min.value) if has_signal(dut, 'y_min') else 0
    y_max_val = int(dut.y_max.value) if has_signal(dut, 'y_max') else 0
    
    hit = (hit_val == 1)
    y_min = q8_8_to_float(y_min_val)
    y_max = q8_8_to_float(y_max_val)
    
    if not hit:
        raise TestFailure("Should hit wall")
    
    # Should be negative-infinity to 0
    INF = 1e10
    if not (abs(y_min) > INF or y_min < -INF):
        raise TestFailure(f"y_min should be negative-infinity, got {y_min}")
    if abs(y_max - 0) > 0.01:
        raise TestFailure(f"y_max should be 0, got {y_max}")
    
    cocotb.log.info(f"Infinity test passed: {y_min} to {y_max}")