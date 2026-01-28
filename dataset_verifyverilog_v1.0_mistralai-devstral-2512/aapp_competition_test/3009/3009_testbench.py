import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
import math

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

# Fixed-point helpers
COORD_BITS = 10  # Q10.6 format (10 integer, 6 fractional)
ENERGY_BITS = 16
RESULT_BITS = 32
FRAC_BITS = 6
INT_BITS = 10

# Scale coordinates
SCALE_COORD = 64  # 2^6
SCALE_ENERGY = 10  # to avoid floating point

def float_to_fixed(f, frac_bits=FRAC_BITS):
    return int(f * (1 << frac_bits))

def fixed_to_float(val, frac_bits=FRAC_BITS):
    return val / (1 << frac_bits)

def euclidean_dist_fixed(x1, y1, x2, y2):
    """Compute sqrt((dx)^2 + (dy)^2) in Q16.16 format"""
    dx = (x2 - x1)
    dy = (y2 - y1)
    # Convert to 32-bit for squared sum
    dx_sq = dx * dx
    dy_sq = dy * dy
    dist_sq = dx_sq + dy_sq  # Q21.12 (10+6+10+6 = 32 bits)
    # Approximate square root (Q16.16)
    # Simple integer sqrt approximation
    if dist_sq == 0:
        return 0
    # Scale to Q16.16 (multiply by 2^(16-12) = 2^4 = 16)
    dist_sq_scaled = dist_sq * 16
    # Integer sqrt
    dist = int(math.isqrt(dist_sq_scaled))
    return dist

# Convex hull functions
def convex_hull_perimeter(points):
    """Compute perimeter of convex hull in fixed-point"""
    if len(points) < 2:
        return 0
    
    # Sort points by x then y
    points_sorted = sorted(points, key=lambda p: (p[0], p[1]))
    
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    
    # Build lower hull
    lower = []
    for p in points_sorted:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    
    # Build upper hull
    upper = []
    for p in reversed(points_sorted):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    
    # Combine (remove last point of each because it's repeated)
    hull = lower[:-1] + upper[:-1]
    
    if len(hull) <= 1:
        return 0
    
    # Compute perimeter
    perimeter = 0
    for i in range(len(hull)):
        x1, y1 = hull[i]
        x2, y2 = hull[(i + 1) % len(hull)]
        perimeter += euclidean_dist_fixed(x1, y1, x2, y2)
    
    return perimeter

@cocotb.test(timeout_time=10000, timeout_unit='ms')
async def test_lighting(dut):
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    test_cases = [
        {
            'lamps': [(10, 10, 5), (10, 20, 5), (20, 10, 5), (20, 20, 5)],
            'expected': 28.0,
            'name': 'sample1'
        },
        {
            'lamps': [(10, 10, 5), (10, 20, 1), (20, 10, 12), (20, 20, 8)],
            'expected': 36.2842712475,
            'name': 'sample2'
        },
        {
            'lamps': [(1, 1, 15), (5, 1, 100), (9, 1, 56), (1, 5, 1), (5, 5, 33), (9, 5, 3)],
            'expected': 28.970562748,
            'name': 'sample3'
        },
        {
            'lamps': [(4, 4, 1), (4, 6, 1), (4, 8, 1), (6, 6, 14), (8, 4, 1), (8, 6, 1), (8, 8, 1), (99, 6, -8)],
            'expected': 32.0,
            'name': 'sample4'
        },
        {
            'lamps': [(4, 4, 2), (8, 8, 3)],
            'expected': None,
            'name': 'impossible'
        }
    ]
    
    for tc in test_cases:
        cocotb.log.info(f"Testing {tc['name']}...")
        lamps = tc['lamps']
        N = len(lamps)
        
        # Compute expected using reference
        total_energy = sum(e for _, _, e in lamps)
        expected_impossible = True
        expected_result = 0.0
        
        if total_energy != 0 and total_energy % 2 == 0:
            target = total_energy // 2
            min_perimeter = float('inf')
            
            # Try all non-empty proper subsets
            for mask in range(1, (1 << N) - 1):
                subset = []
                subset_energy = 0
                for i in range(N):
                    if mask & (1 << i):
                        x, y, e = lamps[i]
                        subset.append((x * SCALE_COORD, y * SCALE_COORD))
                        subset_energy += e
                
                if subset_energy == target:
                    perimeter = convex_hull_perimeter(subset) / (1 << FRAC_BITS)
                    if perimeter < min_perimeter:
                        min_perimeter = perimeter
            
            if min_perimeter < float('inf'):
                expected_impossible = False
                expected_result = min_perimeter
        
        # Write to DUT
        dut.num_lamps.value = N
        
        for i in range(N):
            x, y, e = lamps[i]
            # Scale coordinates to Q10.6
            qx = x * SCALE_COORD
            qy = y * SCALE_COORD
            # Energy scaled
            e_scaled = e * SCALE_ENERGY
            
            if has_signal(dut, f'lamps_x_{i}'):
                getattr(dut, f'lamps_x_{i}').value = clamp_to_width(qx, COORD_BITS)
                getattr(dut, f'lamps_y_{i}').value = clamp_to_width(qy, COORD_BITS)
                getattr(dut, f'lamps_e_{i}').value = from_signed(e_scaled, ENERGY_BITS) if e_scaled < 0 else clamp_to_width(e_scaled, ENERGY_BITS)
            else:
                dut.lamps_x[i].value = clamp_to_width(qx, COORD_BITS)
                dut.lamps_y[i].value = clamp_to_width(qy, COORD_BITS)
                dut.lamps_e[i].value = from_signed(e_scaled, ENERGY_BITS) if e_scaled < 0 else clamp_to_width(e_scaled, ENERGY_BITS)
        
        # Clear remaining lamps
        for i in range(N, 16):
            if has_signal(dut, f'lamps_x_{i}'):
                getattr(dut, f'lamps_x_{i}').value = 0
                getattr(dut, f'lamps_y_{i}').value = 0
                getattr(dut, f'lamps_e_{i}').value = 0
            else:
                dut.lamps_x[i].value = 0
                dut.lamps_y[i].value = 0
                dut.lamps_e[i].value = 0
        
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            for _ in range(10000):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            else:
                raise TestFailure(f"Timeout for {tc['name']}")
        else:
            await Timer(1000, units='ns')
        
        # Check results
        if not is_value_defined(dut.done.value):
            raise TestFailure(f"Done signal undefined for {tc['name']}")
        
        if not is_value_defined(dut.impossible.value):
            raise TestFailure(f"Impossible signal undefined for {tc['name']}")
        
        impossible = int(dut.impossible.value) == 1
        
        if expected_impossible:
            if not impossible:
                raise TestFailure(f"Expected IMPOSSIBLE for {tc['name']}, but got a result")
        else:
            if impossible:
                raise TestFailure(f"Expected result for {tc['name']}, but got IMPOSSIBLE")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result undefined for {tc['name']}")
            
            # Result is Q16.16
            result_raw = int(dut.result.value)
            result_val = fixed_to_float(result_raw, 16)
            
            # Allow small tolerance
            expected = expected_result
            abs_diff = abs(result_val - expected)
            rel_diff = abs_diff / max(1.0, abs(expected))
            
            if abs_diff > 1e-5 and rel_diff > 1e-6:
                raise TestFailure(f"Mismatch for {tc['name']}: expected {expected}, got {result_val} (raw={result_raw})")
        
        cocotb.log.info(f"  PASSED")
