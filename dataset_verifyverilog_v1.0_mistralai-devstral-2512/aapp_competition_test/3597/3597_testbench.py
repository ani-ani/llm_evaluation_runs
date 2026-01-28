import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    if bits == 0: return 0
    max_val = (1 << bits) - 1
    v = int(v)
    if v < 0: v = 0
    if v > max_val: v = max_val
    return v

# Fixed point helpers for Python side validation
def python_physics(w, l, r, h, x1, y1, x2, y2, x3, y3):
    # Returns (d, theta) or None
    # Precision: 0.5 degree steps, d steps of 0.5
    r_f = float(r)
    w_f = float(w)
    l_f = float(l)
    h_f = float(h)
    
    # Search
    # d from r to w-r (center positions)
    d_steps = int((w_f - 2*r_f) / 0.5) + 1
    theta_steps = 361 # 0.0 to 180.0 in 0.5 deg steps
    
    best = None
    
    for i in range(d_steps):
        d = r_f + i * 0.5
        cx = d
        cy = h_f
        
        # Check if cue ball is on table
        if cx < r or cx > w_f - r: continue
        
        for j in range(theta_steps):
            theta = j * 0.5
            rad = math.radians(theta)
            # Vector from cue ball
            vdx = math.cos(rad)
            vdy = math.sin(rad)
            
            # 1. Cue hits Ball 1
            # Line eq: P = C + t * V
            # Ball 1 center P1 = (x1, y1)
            # Closest approach distance must be r + r = 2r
            # (P - C) x V = dist * |V| -> perpendicular dist
            # Actually, intersection of circle (Ball1) and ray (Cue)
            # (P1 - (C + tV))^2 = (2r)^2
            # (P1 - C)^2 - 2t(V . (P1-C)) + t^2 = 4r^2
            # t^2 - 2t(V . D) + |D|^2 - 4r^2 = 0
            
            dx1 = x1 - cx
            dy1 = y1 - cy
            B = -(vdx * dx1 + vdy * dy1) # -V.D
            C_val = dx1*dx1 + dy1*dy1 - (2*r_f)*(2*r_f)
            disc = B*B - C_val
            
            if disc < 0: continue
            sqrt_disc = math.sqrt(disc)
            t1 = B - sqrt_disc
            t2 = B + sqrt_disc
            
            t_hit = -1.0
            if t1 > 1e-5: t_hit = t1
            elif t2 > 1e-5: t_hit = t2
            
            if t_hit < 0: continue
            
            # Impact point P_int
            px = cx + t_hit * vdx
            py = cy + t_hit * vdy
            
            # Vector from Cue to Ball1 at impact
            n_x = x1 - px
            n_y = y1 - py
            n_len = math.hypot(n_x, n_y)
            if n_len < 1e-5: continue
            n_x /= n_len
            n_y /= n_len
            
            # 2. Ball 1 -> Ball 2
            # Ball 1 moves in direction N
            v1_x = n_x
            v1_y = n_y
            
            # Check Ball 1 hits Ball 2
            # Start at (x1, y1)
            dx12 = x2 - x1
            dy12 = y2 - y1
            B12 = -(v1_x * dx12 + v1_y * dy12)
            C12 = dx12*dx12 + dy12*dy12 - (2*r_f)*(2*r_f)
            disc12 = B12*B12 - C12
            if disc12 < 0: continue
            sqrt_d12 = math.sqrt(disc12)
            t12_1 = B12 - sqrt_d12
            t12_2 = B12 + sqrt_d12
            t12 = -1.0
            if t12_1 > 1e-5: t12 = t12_1
            elif t12_2 > 1e-5: t12 = t12_2
            if t12 < 0: continue
            
            # Impact point P12
            p12_x = x1 + t12 * v1_x
            p12_y = y1 + t12 * v1_y
            
            # Vector from Ball1 to Ball2
            n12_x = x2 - p12_x
            n12_y = y2 - p12_y
            n12_len = math.hypot(n12_x, n12_y)
            if n12_len < 1e-5: continue
            n12_x /= n12_len
            n12_y /= n12_len
            
            # Ball 2 moves in direction N12 (falls into hole 1)
            # Hole 1 is (0, l)
            # Check if P12 + k * N12 passes through (0, l)
            # Vector from P12 to Hole
            hx1 = 0 - p12_x
            hy1 = l - p12_y
            # Check parallel: (P12->Hole) x N12 = 0 and dot product > 0
            cross1 = hx1 * n12_y - hy1 * n12_x
            if abs(cross1) > 1e-4: continue
            dot1 = hx1 * n12_x + hy1 * n12_y
            if dot1 <= 0: continue
            
            # 3. Ball 1 -> Ball 3
            # Ball 1 moves N
            dx13 = x3 - x1
            dy13 = y3 - y1
            B13 = -(v1_x * dx13 + v1_y * dy13)
            C13 = dx13*dx13 + dy13*dy13 - (2*r_f)*(2*r_f)
            disc13 = B13*B13 - C13
            if disc13 < 0: continue
            sqrt_d13 = math.sqrt(disc13)
            t13_1 = B13 - sqrt_d13
            t13_2 = B13 + sqrt_d13
            t13 = -1.0
            if t13_1 > 1e-5: t13 = t13_1
            elif t13_2 > 1e-5: t13 = t13_2
            if t13 < 0: continue
            
            # Impact point P13
            p13_x = x1 + t13 * v1_x
            p13_y = y1 + t13 * v1_y
            
            # Vector from Ball1 to Ball3
            n13_x = x3 - p13_x
            n13_y = y3 - p13_y
            n13_len = math.hypot(n13_x, n13_y)
            if n13_len < 1e-5: continue
            n13_x /= n13_len
            n13_y /= n13_len
            
            # Ball 3 moves in direction N13 (falls into hole 2)
            # Hole 2 is (w, l)
            hx2 = w - p13_x
            hy2 = l - p13_y
            cross2 = hx2 * n13_y - hy2 * n13_x
            if abs(cross2) > 1e-4: continue
            dot2 = hx2 * n13_x + hy2 * n13_y
            if dot2 <= 0: continue
            
            # Valid solution
            return (d, theta)
            
    return None

# Test cases
test_cases = [
    # (w, l, r, x1, y1, x2, y2, x3, y3, h)
    (20, 30, 2, 10, 20, 2, 24, 18, 28, 10),
    (20, 30, 2, 15, 20, 2, 24, 18, 28, 10),
]

expected_outputs = [
    (12.74, 127.83),
    None,
]

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_pool_shark(dut):
    # Setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        await Timer(20, units='ns')
        dut.rst_n.value = 1
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await Timer(10, units='ns')
    
    for idx, tc in enumerate(test_cases):
        w, l, r, x1, y1, x2, y2, x3, y3, h = tc
        
        cocotb.log.info(f"Running Test Case {idx+1}: w={w}, l={l}...")
        
        # Set inputs
        if has_signal(dut, 'w'): dut.w.value = w
        if has_signal(dut, 'l'): dut.l.value = l
        if has_signal(dut, 'r'): dut.r.value = r
        if has_signal(dut, 'h'): dut.h.value = h
        if has_signal(dut, 'x1'): dut.x1.value = x1
        if has_signal(dut, 'y1'): dut.y1.value = y1
        if has_signal(dut, 'x2'): dut.x2.value = x2
        if has_signal(dut, 'y2'): dut.y2.value = y2
        if has_signal(dut, 'x3'): dut.x3.value = x3
        if has_signal(dut, 'y3'): dut.y3.value = y3
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            # Combinational?
            await Timer(100, units='ns')
        
        # Wait for result
        max_cycles = 20000
        found = False
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if has_signal(dut, 'result_valid') and int(dut.result_valid.value) == 1:
                found = True
                break
            if has_signal(dut, 'impossible') and int(dut.impossible.value) == 1:
                found = True
                break
        
        if not found:
            raise TestFailure(f"Test {idx+1}: Timeout waiting for result")
        
        # Check result
        exp = expected_outputs[idx]
        if exp is None:
            if not (has_signal(dut, 'impossible') and int(dut.impossible.value) == 1):
                raise TestFailure(f"Test {idx+1}: Expected impossible, but got result")
        else:
            exp_d, exp_t = exp
            # HDL outputs integers * 100
            exp_d_int = int(round(exp_d * 100))
            exp_t_int = int(round(exp_t * 100))
            
            if has_signal(dut, 'impossible') and int(dut.impossible.value) == 1:
                raise TestFailure(f"Test {idx+1}: Expected solution, but got impossible")
            
            if has_signal(dut, 'd_out') and has_signal(dut, 'theta_out'):
                d_out = int(dut.d_out.value)
                theta_out = int(dut.theta_out.value)
                
                # Allow small rounding errors due to fixed point vs float
                if abs(d_out - exp_d_int) > 5 or abs(theta_out - exp_t_int) > 5:
                     raise TestFailure(f"Test {idx+1}: Result mismatch. Exp ({exp_d}, {exp_t}), Got ({d_out/100.0}, {theta_out/100.0})")
            else:
                 raise TestFailure("Result signals missing")
