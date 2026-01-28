import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Fixed-point scaling constants
INT_BITS = 12
FRAC_BITS = 12
SCALE_XY = 1 << FRAC_BITS
SCALE_VW = 1 << 8  # Q16.8 -> 8 frac bits
RESULT_FRAC_BITS = 16
RESULT_SCALE = 1 << RESULT_FRAC_BITS

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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

def compute_ref_time(x_in, y_in, v_in, w_in):
    """Reference Python computation for verification"""
    # Scale from int to float
    x = x_in / SCALE_XY
    y = y_in / SCALE_XY
    v = v_in / SCALE_VW
    w = w_in / SCALE_VW
    
    d = math.sqrt(x*x + y*y)
    alpha = math.atan2(y, x)  # -pi to pi
    
    # Case 1: Rotate, Move, Rotate (only if w != 0)
    time1 = float('inf')
    if w != 0:
        abs_w = abs(w)
        if d <= 2 * v / abs_w:
            # Optimal: rotate to alpha, then go straight
            time1 = abs(alpha) / abs_w + d / v
        else:
            # Rotate, go, rotate
            # This is simplified - actual optimal may need solving
            time1 = (abs(alpha) + math.pi) / abs_w + (d - 2*v/abs_w) / v
    
    # Case 2: Move, Rotate (only if target is behind start)
    # Actually, if target is behind (y < 0), we can go straight to (x,0), rotate pi
    time2 = float('inf')
    if y < 0:
        # Go straight to (x,0) first
        if w != 0:
            time2 = abs(x) / v + math.pi / abs(w)
    
    # Case 3: Just move (if aligned)
    time3 = float('inf')
    if y == 0:
        time3 = d / v
    
    # Case 4: Just rotate if target is at origin (but problem says (x,y) != (0,0))
    
    min_time = min(time1, time2, time3)
    
    # Scale back to Q16.16
    return int(min_time * RESULT_SCALE)

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

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_hovercraft(dut):
    # Setup clock
    CLK_NS = 10
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (x, y, v, w, expected_time_sec)
    test_cases = [
        (20, 0, 1.00, 0.10, 20.00000000),
        (-10, 10, 10.00, 1.00, 3.14159265),
        (0, 20, 1.00, 0.10, 28.26445910),
        (-997, -3, 5.64, 2.15, 177.76915187),
    ]
    
    passed = 0
    failed = 0
    
    for i, (x, y, v, w, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: ({x}, {y}) v={v}, w={w}")
        
        # Scale inputs
        x_scaled = int(x * SCALE_XY)
        y_scaled = int(y * SCALE_XY)
        v_scaled = int(v * SCALE_VW)
        w_scaled = int(w * SCALE_VW)
        
        # Compute expected scaled result
        expected_scaled = int(expected * RESULT_SCALE)
        
        try:
            # Assign inputs (24-bit as per spec)
            dut.x.value = x_scaled & 0xFFFFFF
            dut.y.value = y_scaled & 0xFFFFFF
            dut.v.value = v_scaled & 0xFFFFFF
            dut.w.value = w_scaled & 0xFFFFFF
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result_time.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result_time.value)
            
            # Convert to float for comparison
            result_float = fixed_to_float(result, RESULT_FRAC_BITS)
            expected_float = expected
            
            abs_error = abs(result_float - expected_float)
            
            if abs_error > 1e-3:
                raise TestFailure(f"Expected {expected_float:.8f}, got {result_float:.8f}, error={abs_error:.8f}")
            
            cocotb.log.info(f"PASS: Result {result_float:.8f} within tolerance")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")