import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

# Interval scaling: map real value to 8-bit signed
# Scale factor = 8 (so 1.0 maps to 8, 16 maps to 128 which is out of range)
# Actually, we need to fit [-16, 16] into 8-bit signed
# 8-bit signed range is -128 to 127
# Let's scale by 8: value * 8 fits in -128 to 128
# But 128 is out of range, so max value is 15.999... which is fine
SCALE = 8
MAX_SIGNED = 127
MIN_SIGNED = -128

def float_to_fixed(f, scale=SCALE):
    return int(f * scale)

async def write_interval(dut, idx, start, end, width=8):
    """Write interval to dut"""
    start_fixed = float_to_fixed(start)
    end_fixed = float_to_fixed(end)
    # Clamp to signed 8-bit range
    start_clamped = clamp_to_width(from_signed(start_fixed, width), width)
    end_clamped = clamp_to_width(from_signed(end_fixed, width), width)
    
    if idx == 1:
        dut.s1.value = start_clamped
        dut.e1.value = end_clamped
    else:
        dut.s2.value = start_clamped
        dut.e2.value = end_clamped

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_intersection(dut):
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
    
    # Test cases: (s1, e1, s2, e2, expected_result, description)
    test_cases = [
        # From problem examples
        (1, 2, 2, 3, 0, "(1,2) and (2,3): intersection length 0"),
        (-1, 1, 0, 4, 0, "(-1,1) and (0,4): intersection length 1"),
        (-3, -1, -5, 5, 1, "(-3,-1) and (-5,5): intersection length 2 (prime)"),
        (-2, 2, -4, 0, 1, "(-2,2) and (-4,0): intersection length 2 (prime)"),
        (-11, 2, -1, -1, 0, "(-11,2) and (-1,-1): intersection length 0"),
        (1, 2, 3, 5, 0, "(1,2) and (3,5): no intersection"),
        (1, 2, 1, 2, 0, "(1,2) and (1,2): intersection length 1"),
        (-2, -2, -3, -2, 0, "(-2,-2) and (-3,-2): intersection length 0"),
        # Additional edge cases
        (0, 0, 0, 0, 0, "(0,0) and (0,0): length 0"),
        (0, 1, 0, 1, 0, "(0,1) and (0,1): length 1"),
        (0, 3, 0, 3, 0, "(0,3) and (0,3): length 3 (prime) -> YES"),
        (0, 5, 1, 4, 0, "(0,5) and (1,4): length 3 (prime) -> YES"),
        (0, 10, 2, 8, 0, "(0,10) and (2,8): length 6"),
        (-10, 10, -5, 5, 0, "(-10,10) and (-5,5): length 10"),
    ]
    
    passed = failed = 0
    for i, (s1, e1, s2, e2, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs
            await write_interval(dut, 1, s1, e1)
            await write_interval(dut, 2, s2, e2)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                # Wait for done
                done = False
                for _ in range(20):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                if not done:
                    raise TestFailure("Done signal not asserted within 20 cycles")
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            # Since result is 1-bit, it's already 0 or 1
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")