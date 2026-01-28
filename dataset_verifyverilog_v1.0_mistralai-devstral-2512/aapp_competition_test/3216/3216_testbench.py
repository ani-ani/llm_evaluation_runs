import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

CLK_NS = 10
MAX_CYCLES = 500

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def parse_decimal(s):
    # s like '0.142857' or '1.6'
    parts = s.split('.')
    int_part = int(parts[0])
    frac_part = parts[1]
    total_digits = len(frac_part)
    return int_part, frac_part, total_digits

def compute_fraction(s, repeat_digits):
    # Convert to fraction using integer math
    int_part, frac_part, total_digits = parse_decimal(s)
    A = total_digits
    B = repeat_digits
    # Non-repeating part
    non_rep = int(frac_part[:-B]) if B < A else 0
    # Repeating part
    rep = int(frac_part[-B:]) if B > 0 else 0
    # N1 = int_part * 10^A + non_rep
    N1 = int_part * (10 ** A) + non_rep
    N2 = rep
    # Denominator part for repeating: 10^B - 1
    denom_rep = (10 ** B) - 1
    # Combined numerator: N1 * denom_rep + N2
    num = N1 * denom_rep + N2
    den = (10 ** A) * denom_rep
    # Reduce
    g = math.gcd(num, den)
    return num // g, den // g

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_repeating_decimal(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ("0.142857", 6, 1, 7),
        ("1.6", 1, 5, 3),
        ("123.456", 2, 61111, 495),
    ]
    
    passed = 0
    failed = 0
    
    for i, (s, rep, exp_num, exp_den) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {s} repeating {rep}")
        try:
            int_part, frac_part, total_digits = parse_decimal(s)
            # Create scaled value: remove decimal point
            full_str = str(int_part) + frac_part
            scaled_val = int(full_str)
            
            # Check bit widths
            scaled_width = 12
            if scaled_val >= (1 << scaled_width):
                cocotb.log.warning(f"Scaled value {scaled_val} exceeds 12 bits, truncating")
                scaled_val = scaled_val & ((1 << scaled_width) - 1)
            
            # Assign inputs
            dut.scaled_value.value = scaled_val
            dut.total_digits.value = total_digits
            dut.repeat_digits.value = rep
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read outputs
            num = int(dut.numerator.value)
            den = int(dut.denominator.value)
            
            # Compare
            if num != exp_num or den != exp_den:
                raise TestFailure(f"Expected {exp_num}/{exp_den}, got {num}/{den}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
