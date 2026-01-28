import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helpers
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Fixed-point conversion
FIXED_BITS = 16  # Q16.16
SCALE = 1 << FIXED_BITS

def float_to_fixed(f):
    return int(f * SCALE)

def fixed_to_float(v):
    return v / SCALE

# Compute spiral detachment point (Python reference)
def compute_spiral_point(b, tx, ty):
    # Solve for phi where line from spiral point at phi hits target
    # Spiral: r = b * phi
    # Position: x = r * cos(phi), y = r * sin(phi)
    # Velocity: dx/dphi = b*cos(phi) - r*sin(phi), dy/dphi = b*sin(phi) + r*cos(phi)
    
    best_phi = 0
    best_dist = float('inf')
    
    # Search over phi
    for phi in range(0, 62832):  # 0 to 2*pi*10 (10 rotations) with 0.0001 rad steps
        phi_val = phi * 0.0001
        r = b * phi_val
        
        if r < 1e-6:
            continue
            
        # Spiral point
        x_s = r * math.cos(phi_val)
        y_s = r * math.sin(phi_val)
        
        # Velocity vector (normalized direction)
        v_x = b * math.cos(phi_val) - r * math.sin(phi_val)
        v_y = b * math.sin(phi_val) + r * math.cos(phi_val)
        
        # Normalize velocity
        v_mag = math.sqrt(v_x*v_x + v_y*v_y)
        if v_mag < 1e-9:
            continue
        v_x /= v_mag
        v_y /= v_mag
        
        # Solve for t: (x_s + v_x*t - tx)^2 + (y_s + v_y*t - ty)^2 = 0
        # Linear equation: (v_x)*(x_s + v_x*t - tx) + (v_y)*(y_s + v_y*t - ty) = 0
        # t = -v_x*(x_s-tx) - v_y*(y_s-ty) / (v_x^2 + v_y^2) = -v_x*(x_s-tx) - v_y*(y_s-ty)
        
        dot = v_x * (x_s - tx) + v_y * (y_s - ty)
        t = -dot
        
        if t < 0:
            continue
            
        # Check if trajectory intersects spiral
        # Line segment: (x_s, y_s) -> (x_s + v_x*t, y_s + v_y*t)
        # Check intersection with spiral r = b*phi for phi > phi_val
        
        target_x = x_s + v_x * t
        target_y = y_s + v_y * t
        
        # Distance from target to spiral at same angle
        dist_to_target = math.sqrt((target_x - tx)**2 + (target_y - ty)**2)
        
        # Check if line segment intersects spiral
        intersects = False
        check_steps = 1000
        for i in range(1, check_steps):
            check_phi = phi_val + i * 0.01
            check_r = b * check_phi
            if check_r > math.sqrt(target_x**2 + target_y**2) + 100:
                break
                
            check_x = check_r * math.cos(check_phi)
            check_y = check_r * math.sin(check_phi)
            
            # Check if point is close to line segment
            # Vector from start to check point
            dx1 = check_x - x_s
            dy1 = check_y - y_s
            # Vector from start to end of segment
            dx2 = target_x - x_s
            dy2 = target_y - y_s
            
            # Cross product to check if on same side
            cross = dx1 * dy2 - dy1 * dx2
            if abs(cross) < 1e-3:
                # Check if within segment bounds
                dot_check = dx1 * dx2 + dy1 * dy2
                if 0 < dot_check < dx2*dx2 + dy2*dy2:
                    intersects = True
                    break
                    
        if not intersects and dist_to_target < best_dist:
            best_dist = dist_to_target
            best_phi = phi_val
            
    # Return best point
    r = b * best_phi
    x = r * math.cos(best_phi)
    y = r * math.sin(best_phi)
    return x, y

# Test cases
test_cases = [
    (0.5, -5.301, 3.098, -1.26167861, 3.88425357),
    (0.5, 8, 8, 9.21068947, 2.56226688),
    (1.0, 8, 8, 6.22375968, -0.31921472),
    (0.5, -8, 8, -4.36385220, 9.46891588),
    (0.5, 0, -8, -3.60855706, -3.61140618),
]

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_archimedes_spiral(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, (b, tx, ty, exp_x, exp_y) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: b={b}, target=({tx}, {ty})")
        
        try:
            # Compute expected using Python reference
            ref_x, ref_y = compute_spiral_point(b, tx, ty)
            cocotb.log.info(f"Reference result: ({ref_x:.6f}, {ref_y:.6f})")
            
            # Convert to fixed-point
            b_fp = float_to_fixed(b)
            tx_fp = float_to_fixed(tx)
            ty_fp = float_to_fixed(ty)
            
            # Assign inputs
            if has_signal(dut, 'b'):
                dut.b.value = b_fp
            if has_signal(dut, 'tx'):
                dut.tx.value = tx_fp
            if has_signal(dut, 'ty'):
                dut.ty.value = ty_fp
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(1000, units='ns')
            
            # Read result
            if has_signal(dut, 'x_det') and has_signal(dut, 'y_det'):
                x_det = int(dut.x_det.value)
                y_det = int(dut.y_det.value)
            elif has_signal(dut, 'result'):
                # Packed result
                result = int(dut.result.value)
                x_det = (result >> 32) & 0xFFFFFFFF
                y_det = result & 0xFFFFFFFF
                # Sign extend if negative
                if x_det >= 0x80000000:
                    x_det = x_det - 0x100000000
                if y_det >= 0x80000000:
                    y_det = y_det - 0x100000000
            else:
                raise TestFailure("No result signals found")
            
            x_f = fixed_to_float(x_det)
            y_f = fixed_to_float(y_det)
            
            cocotb.log.info(f"Module result: ({x_f:.6f}, {y_f:.6f})")
            
            # Check error tolerance (10^-5)
            err_x = abs(x_f - ref_x)
            err_y = abs(y_f - ref_y)
            
            # Use relative or absolute error
            if err_x > 1e-5 and abs(ref_x) > 0:
                if (err_x / abs(ref_x)) > 1e-5:
                    raise TestFailure(f"X error too large: {err_x} (expected < 1e-5)")
            if err_y > 1e-5 and abs(ref_y) > 0:
                if (err_y / abs(ref_y)) > 1e-5:
                    raise TestFailure(f"Y error too large: {err_y} (expected < 1e-5)")
            
            cocotb.log.info(f"PASS: X error={err_x:.2e}, Y error={err_y:.2e}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
    
    cocotb.log.info(f"\nResults: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")