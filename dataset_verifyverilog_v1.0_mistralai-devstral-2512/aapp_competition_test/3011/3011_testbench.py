import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
ARRAY_SIZE = 19  # Max decimal digits
CLK_NS = 10
MAX_CYCLES = 1000

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

def decimal_to_scaled(n):
    """Convert decimal int to Q32.32 scaled representation"""
    return n << 32

def count_decimal_digits(n):
    """Count number of decimal digits"""
    if n == 0: return 1
    count = 0
    while n > 0:
        n //= 10
        count += 1
    return count

def is_hill_number(n):
    """Check if number is a hill number"""
    s = str(n)
    state = 0  # 0=rising, 1=falling
    for i in range(1, len(s)):
        if s[i] > s[i-1]:
            if state == 1:
                return False
            state = 0
        elif s[i] < s[i-1]:
            state = 1
    return True

def count_hill_numbers(n):
    """Count hill numbers <= n"""
    count = 0
    for i in range(1, n + 1):
        if is_hill_number(i):
            count += 1
    return count

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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_hill_number_counter(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (10, 10, "Two-digit number"),
        (55, 55, "Repeating digits"),
        (101, -1, "Invalid - falls then rises"),
        (1234321, 94708, "Large hill number"),
        (1000, 715, "Thousand"),
        (1, 1, "Single digit"),
        (9, 9, "Single digit max"),
        (12, 12, "Two digit rise"),
        (21, 21, "Two digit fall"),
        (111, 111, "All same"),
        (987654321, 5267570, "Large descending"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n})")
        try:
            # Calculate expected values
            is_hill = is_hill_number(n)
            if is_hill:
                exp_result = expected
                exp_hill = 1
            else:
                exp_result = 0xFFFFFFFF
                exp_hill = 0
            
            # Setup input
            scaled = decimal_to_scaled(n)
            digits_len = count_decimal_digits(n)
            
            if has_signal(dut, 'n_scaled'):
                dut.n_scaled.value = scaled
            if has_signal(dut, 'digits_len'):
                dut.digits_len.value = digits_len
            
            if is_seq:
                # Start pulse
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(200, units='ns')
            
            # Check results
            result_val = safe_int(dut.result.value, 0)
            is_hill_val = safe_int(dut.is_hill.value, 0)
            
            # Convert result if signed (handle -1 encoding)
            if result_val >= (1 << 31):
                result_val = result_val - (1 << 32)  # Convert to signed
            
            cocotb.log.info(f"  Result: {result_val}, is_hill: {is_hill_val}, Expected: {exp_result}")
            
            if result_val != exp_result:
                raise TestFailure(f"Result mismatch: expected {exp_result}, got {result_val}")
            
            if is_hill_val != exp_hill:
                raise TestFailure(f"is_hill mismatch: expected {exp_hill}, got {is_hill_val}")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"Test Summary: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")