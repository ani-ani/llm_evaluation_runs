import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Fixed-point constants
SCALE_COORD = 1024  # 2^10
SCALE_SPEED = 65536 # 2^16
DATA_WIDTH = 32
MAX_VAL = (1 << DATA_WIDTH) - 1

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def float_to_fixed(f, scale):
    return int(f * scale)

def fixed_to_float(v, scale):
    return v / scale

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if hasattr(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def python_solution(xs, ys, ss, ri, rf, xa, ya, sa):
    # Coordinates in meters
    xs_m, ys_m = xs, ys
    xa_m, ya_m = xa, ya
    ss_m, sa_m = ss, sa
    ri_m, rf_m = ri, rf
    
    # Distance from start to center
    D = math.hypot(xa_m - xs_m, ya_m - ys_m)
    
    # Time when radius stops shrinking (if it does)
    t_stop = (ri_m - rf_m) / ss_m if ss_m > 0 else float('inf')
    
    # Binary search for optimal time t
    # Damage is time spent outside zone. 
    # If arrive at t, and zone shrinks to r(t).
    # We want to minimize max(0, t - t_in)
    # where t_in is the earliest time we can be inside.
    
    # Strategy: Find minimal damage d.
    # d = max(0, t - t_min_arrival(t))
    # where t_min_arrival(t) is the earliest time we can reach zone radius r(t).
    # r(t) = max(rf, ri - ss*t)
    # distance to cover = max(0, D - r(t))
    # time to cover = distance / sa
    # t_min_arrival(t) = time_to_cover
    # Check if we can actually arrive by t: time_to_cover <= t
    # If yes, damage = t - time_to_cover (time outside zone until arrival)
    # Actually, if we arrive at t_a <= t, we are safe from t_a onwards.
    # Damage = t_a (if we arrive during shrinking).
    # Wait, the damage is taken at 1 per second while outside.
    # If we arrive at t_a, damage taken = t_a (if we were outside for whole time).
    # But if we arrive inside the initial zone (D <= ri), we take 0 damage.
    
    # Simplification: The function damage(t) is convex.
    # We iterate t from 0 to t_stop + (D/sa).
    # Actually, just binary search t for optimal arrival.
    # But t is the time we *arrive*.
    # Let's binary search t (arrival time).
    # Radius at t: r_t = max(rf, ri - ss*t).
    # Distance to cover: dist = max(0, D - r_t).
    # Time needed: t_needed = dist / sa.
    # Constraint: t_needed <= t (we can't travel back in time).
    # If constraint holds, damage = t (since we are outside until t).
    # Wait, if we arrive at t, and we were outside, we took t damage.
    # We want to minimize t.
    # But t must be >= t_needed.
    # So we want to find minimal t such that t >= t_needed.
    # This is essentially finding intersection of t and t_needed(t).
    
    # Better approach: Binary search for damage d.
    # Can we achieve damage <= d?
    # This means we arrive by time t_arr = d.
    # Radius at t_arr: r = max(rf, ri - ss*d).
    # Dist to cover: dist = max(0, D - r).
    # Can we cover dist in time d? sa * d >= dist.
    # If yes, d is achievable.
    
    lo, hi = 0.0, 1e9 + 10000.0
    for _ in range(64):
        mid = (lo + hi) / 2
        r_t = max(rf_m, ri_m - ss_m * mid)
        dist = max(0.0, D - r_t)
        if sa_m * mid >= dist:
            hi = mid
        else:
            lo = mid
    return hi

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_min_damage(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    
    test_cases = [
        (2.0, 1.0, 1.0, 3.0, 2.0, 2.0, 5.0, 1.0, 2.0),
        (2.0, 1.0, 1.0, 3.0, 2.0, 2.0, 4.0, 1.0, 0.0),
    ]
    
    for xs, ys, ss, ri, rf, xa, ya, sa, expected in test_cases:
        # Scale inputs
        dut.xs.value = float_to_fixed(xs, SCALE_COORD)
        dut.ys.value = float_to_fixed(ys, SCALE_COORD)
        dut.ss.value = float_to_fixed(ss, SCALE_SPEED)
        dut.ri.value = float_to_fixed(ri, SCALE_COORD)
        dut.rf.value = float_to_fixed(rf, SCALE_COORD)
        dut.xa.value = float_to_fixed(xa, SCALE_COORD)
        dut.ya.value = float_to_fixed(ya, SCALE_COORD)
        dut.sa.value = float_to_fixed(sa, SCALE_SPEED)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        result_val = int(dut.result.value)
        result_float = fixed_to_float(result_val, SCALE_SPEED) # Result is damage (time)
        
        if abs(result_float - expected) > 1e-3:
            raise TestFailure(f"Input: {(xs,ys,ss,ri,rf,xa,ya,sa)} Expected {expected}, got {result_float}")
