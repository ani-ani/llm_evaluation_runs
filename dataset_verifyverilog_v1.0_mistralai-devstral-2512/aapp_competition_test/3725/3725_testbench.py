import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
TIME_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 2500  # Slightly above max test case requirement

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
    if v < 0: return 0  # Unsigned clamp
    return min((1 << bits) - 1, v)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def python_solve(m, h1, a1, x1, y1, h2, a2, x2, y2):
    seen1 = {}
    seen2 = {}
    t1 = None
    t2 = None
    s1 = 0
    s2 = 0
    
    # Find first occurrence and cycle info for frog 1
    for t in range(MAX_CYCLES):
        if h1 == a1 and t1 is None:
            t1 = t
        if h1 in seen1 and t1 is not None:
            s1 = t - seen1[h1]
            break
        seen1[h1] = t
        h1 = (x1 * h1 + y1) % m
    
    # Find first occurrence and cycle info for frog 2
    h2_orig = h2
    for t in range(MAX_CYCLES):
        if h2 == a2 and t2 is None:
            t2 = t
        if h2 in seen2 and t2 is not None:
            s2 = t - seen2[h2]
            break
        seen2[h2] = t
        h2 = (x2 * h2 + y2) % m
    
    if t1 is None or t2 is None:
        return -1
    
    # Check simple sync
    if t1 == t2:
        return t1
    
    # Check if one is in cycle and other matches
    u1 = seen1[a1] if a1 in seen1 else -1
    u2 = seen2[a2] if a2 in seen2 else -1
    
    if u1 != -1 and s1 > 0:
        # Frog 1 is cycling
        if u1 <= t2:
            if u1 in seen2 and seen2[a2] == u1:
                return u1
        else:
            # t2 is earlier, check if t2 matches u1's cycle
            diff = u1 - t2
            if diff % s2 == 0:
                return u1
                
    if u2 != -1 and s2 > 0:
        # Frog 2 is cycling
        if u2 <= t1:
            if u2 in seen1 and seen1[a1] == u2:
                return u2
        else:
            diff = u2 - t1
            if diff % s1 == 0:
                return u2
                
    # Both are cycling
    if s1 > 0 and s2 > 0:
        # Solve t1 + k1 * s1 == t2 + k2 * s2
        # t1 + k1*s1 = t2 (mod s2)
        # k1*s1 = (t2 - t1) (mod s2)
        target = (t2 - t1) % s2
        # Extended Euclidean for k1
        for k1 in range(s2):
            if (k1 * s1) % s2 == target:
                return t1 + k1 * s1
    
    return -1

def pack_inputs(m, h1, a1, x1, y1, h2, a2, x2, y2):
    return {
        'm': m,
        'h1_init': h1, 'a1': a1, 'x1': x1, 'y1': y1,
        'h2_init': h2, 'a2': a2, 'x2': x2, 'y2': y2
    }

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_frog_and_flower(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (5, 4, 2, 1, 1, 0, 1, 2, 3),
        (1023, 1, 2, 1, 0, 1, 2, 1, 1),
        (1023, 1, 2, 1, 2, 1, 2, 1, 2),
        (2, 0, 1, 1, 0, 1, 0, 0, 1),
        (17, 15, 12, 15, 12, 12, 14, 1, 11),
        (29, 4, 0, 1, 1, 25, 20, 16, 0),
        (91, 9, 64, 75, 32, 60, 81, 35, 46),
        (91, 38, 74, 66, 10, 40, 76, 17, 13),
        (100, 11, 20, 99, 31, 60, 44, 45, 64),
        (9999, 4879, 6224, 63, 7313, 4279, 6583, 438, 1627),
        (10000, 8681, 4319, 9740, 5980, 24, 137, 462, 7971),
        (100000, 76036, 94415, 34870, 43365, 56647, 26095, 88580, 30995),
        (100000, 90861, 77058, 96282, 30306, 45940, 25601, 17117, 48287),
        (1000000, 220036, 846131, 698020, 485511, 656298, 242999, 766802, 905433),
        (1000000, 536586, 435396, 748740, 34356, 135075, 790803, 547356, 534911),
    ]
    
    passed = 0
    failed = 0
    
    for i, (m, h1, a1, x1, y1, h2, a2, x2, y2) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: m={m}, h1={h1}, a1={a1}, h2={h2}, a2={a2}")
        
        try:
            if has_signal(dut, 'clk'):
                await reset_dut(dut)
                
            # Calculate expected result
            exp = await python_solve(m, h1, a1, x1, y1, h2, a2, x2, y2)
            
            # Drive inputs
            dut.m.value = clamp_to_width(m, DATA_WIDTH) if m < (1<<DATA_WIDTH) else (1<<DATA_WIDTH)-1
            dut.h1_init.value = h1
            dut.a1.value = a1
            dut.x1.value = x1
            dut.y1.value = y1
            dut.h2_init.value = h2
            dut.a2.value = a2
            dut.x2.value = x2
            dut.y2.value = y2
            
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(1000, units='ns')
                
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
                
            res = int(dut.result.value)
            
            # Handle signed result (32-bit)
            if res >= (1 << (TIME_WIDTH - 1)):
                res = res - (1 << TIME_WIDTH)
            
            if res != exp:
                raise TestFailure(f"Expected {exp}, got {res}")
                
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed")
