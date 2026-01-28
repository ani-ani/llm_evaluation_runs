import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 16
FRAC_BITS = 16
CLK_NS = 10
MAX_CYCLES = 100

# Fixed-point constants
PI_FIXED = 0x3243F  # 3.141592653589793 in Q16.16
ONE_THIRD_FIXED = 0x5555  # 0.3333333333333333 in Q16.16

def to_fixed(f, frac=16):
    return int(f * (1 << frac))

def from_fixed(v, frac=16):
    return v / (1 << frac)

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    min_val = -(1 << bits)
    if v > max_val:
        return max_val
    if v < min_val:
        return min_val
    return v

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cone_volume(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (5.0, 12.0, 314.15926535897927),
        (10.0, 15.0, 1570.7963267948965),
        (19.0, 17.0, 6426.651371693521),
    ]
    
    passed = 0
    failed = 0
    
    for i, (r_float, h_float, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: r={r_float}, h={h_float}")
        
        # Convert to fixed-point
        r_fixed = to_fixed(r_float, FRAC_BITS)
        h_fixed = to_fixed(h_float, FRAC_BITS)
        
        try:
            # Apply clamp to 16-bit signed range
            r_clamped = clamp_to_width(r_fixed, 16)
            h_clamped = clamp_to_width(h_fixed, 16)
            
            dut.r.value = r_clamped
            dut.h.value = h_clamped
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result_signed = int(dut.result.value)
            # Convert from signed 32-bit to Python int
            if result_signed < 0:
                result_signed = result_signed + (1 << 32)
            
            result_float = from_fixed(result_signed, FRAC_BITS)
            
            # Check with relative tolerance
            if not math.isclose(result_float, expected, rel_tol=0.001):
                raise TestFailure(f"Expected {expected:.6f}, got {result_float:.6f}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {result_float:.6f}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")