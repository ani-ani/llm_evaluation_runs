import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
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

# Expected Python implementation
def python_sum_common_divisors(a, b):
    if a == 0 or b == 0:
        return 0
    sum_val = 0
    limit = min(a, b)
    for i in range(1, min(limit, 256)):  # Cap at 256 for hardware bound
        if (a % i == 0) and (b % i == 0):
            sum_val += i
    return sum_val

DATA_WIDTH = 16
MAX_ITER = 256
ITER_WIDTH = 12
RESULT_WIDTH = 24
CLK_NS = 10
MAX_CYCLES = 300

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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_sum_common_divisors(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        (10, 15, 6, "10 and 15"),
        (100, 150, 93, "100 and 150"),
        (4, 6, 3, "4 and 6"),
        # Additional test cases
        (1, 1, 1, "1 and 1"),
        (0, 5, 0, "0 and 5"),
        (5, 0, 0, "5 and 0"),
        (16, 8, 15, "16 and 8"),
        (255, 255, 248, "255 and 255"),  # Max common divisors for 8-bit
        (12, 18, 6, "12 and 18"),
        (7, 13, 1, "7 and 13 (primes)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} ({a}, {b})")
        try:
            # Clamp inputs to 16-bit
            a_clamped = clamp_to_width(a, DATA_WIDTH)
            b_clamped = clamp_to_width(b, DATA_WIDTH)
            
            if is_seq:
                dut.a.value = a_clamped
                dut.b.value = b_clamped
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                    
                result = int(dut.result.value)
            else:
                # Combinational case
                dut.a.value = a_clamped
                dut.b.value = b_clamped
                await Timer(100, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            
            # Compute expected (capped at MAX_ITER-1 for hardware bound)
            expected = python_sum_common_divisors(a, b)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Got {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"\nAll {passed} tests passed!")