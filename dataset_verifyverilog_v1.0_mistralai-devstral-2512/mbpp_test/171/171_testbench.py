import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper functions (as per rules)
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
Q8_INT = 8
Q8_FRAC = 8
Q16_INT = 16
Q16_FRAC = 16

def float_to_q8(f):
    return int(f * (1 << Q8_FRAC))

def q8_to_float(v):
    return v / (1 << Q8_FRAC)

# For pentagon perimeter: input side is Q8.8, output perimeter is Q8.8 (16-bit)
# Our module outputs lower 16 bits of 5*Q8.8, which is exactly 5*side in Q8.8 if side is integer
# but for fractional, it's truncated. However test cases are integers.

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_pentagon_perimeter(dut):
    """Test pentagon perimeter calculation"""
    # Combinational module: no clock or reset needed
    
    test_cases = [
        (5, 25, "integer 5"),
        (10, 50, "integer 10"),
        (15, 75, "integer 15"),
        (0, 0, "zero"),
        (1, 5, "one"),
        (255, 1275, "max int 255")  # 5*255=1275, fits in 16-bit Q8.8 (max 65535.996)
    ]
    
    passed = 0
    failed = 0
    
    for i, (side_int, exp_perim_int, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Convert to Q8.8 (no fractional part for these integers)
            side_q8 = float_to_q8(side_int)
            
            # Assign to input port
            if has_signal(dut, 'side'):
                dut.side.value = clamp_to_width(side_q8, 16)
            else:
                raise TestFailure("Signal 'side' not found")
            
            # Combinational: allow some time for propagation
            await Timer(10, units='ns')
            
            # Read output
            if not has_signal(dut, 'perimeter'):
                raise TestFailure("Signal 'perimeter' not found")
            
            if not is_value_defined(dut.perimeter.value):
                raise TestFailure("Result undefined")
            
            result_raw = int(dut.perimeter.value)
            # Convert back from Q8.8 to integer for comparison (assuming output is Q8.8)
            result_int = int(q8_to_float(result_raw))
            
            if result_int != exp_perim_int:
                raise TestFailure(f"Expected perimeter {exp_perim_int} (Q8.8 0x{exp_perim_int<<8:x}), got {result_int} (Q8.8 0x{result_raw:x})")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Add small delay between tests
        await Timer(1, units='ns')
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed")