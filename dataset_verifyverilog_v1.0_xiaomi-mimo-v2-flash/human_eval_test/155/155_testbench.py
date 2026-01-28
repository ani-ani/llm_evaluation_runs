import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

CLK_NS = 10
MAX_CYCLES = 100

def abs16(val):
    """Convert signed 16-bit value to absolute value"""
    if val < 0:
        return -val
    return val

def count_even_odd_digits(n):
    """Python reference function"""
    if n == 0:
        return (1, 0)
    n = abs(n)
    even = 0
    odd = 0
    while n > 0:
        digit = n % 10
        if digit % 2 == 0:
            even += 1
        else:
            odd += 1
        n //= 10
    return (even, odd)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_even_odd_count(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (7, (0, 1), "single digit odd"),
        (-78, (1, 1), "two digit negative"),
        (3452, (2, 2), "four digit"),
        (346211, (3, 3), "six digit (truncated)"),
        (-345821, (3, 3), "six digit negative (truncated)"),
        (-2, (1, 0), "single digit negative even"),
        (-45347, (2, 3), "five digit negative"),
        (0, (1, 0), "zero"),
        (123, (1, 2), "three digit positive"),
        (-12, (1, 1), "two digit negative"),
    ]
    
    passed = failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input {inp}")
        try:
            # Clamp to 16-bit signed range
            if inp < -32768 or inp > 32767:
                cocotb.log.info(f"  Clamping {inp} to 16-bit range")
                if inp < -32768:
                    inp = -32768
                else:
                    inp = 32767
            
            # Set input
            dut.num.value = inp if inp >= 0 else (1 << 16) + inp
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read results
            even = int(dut.even_count.value) if is_value_defined(dut.even_count.value) else 0
            odd = int(dut.odd_count.value) if is_value_defined(dut.odd_count.value) else 0
            
            if (even, odd) != exp:
                raise TestFailure(f"Expected {exp}, got ({even}, {odd})")
            passed += 1
            cocotb.log.info(f"  PASS: ({even}, {odd})")
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")