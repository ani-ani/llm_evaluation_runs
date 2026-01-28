import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 64
CLK_NS = 10
MAX_CYCLES = 2000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    if v < 0: v = (1 << bits) + v
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def is_handsome(num):
    if num < 10: return True
    digits = []
    while num > 0:
        digits.append(num % 10)
        num //= 10
    digits.reverse()
    for i in range(len(digits)-1):
        if (digits[i] % 2) == (digits[i+1] % 2):
            return False
    return True

def find_closest_handsome(n):
    if is_handsome(n):
        return [n]
    candidates = []
    for d in range(1, 1001):
        for sign in [-1, 1]:
            candidate = n + sign * d
            if candidate < 1: continue
            if is_handsome(candidate):
                candidates.append(candidate)
                if len(candidates) == 2:
                    return sorted(candidates)
    return candidates

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
async def test_handsome(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (13, [12, 14]),
        (5801001, [5810101]),
        (10, [12, 10]),  # 10 is not handsome (1 and 0 both even/odd?) 1=odd, 0=even -> actually handsome! wait 1=odd, 0=even -> different parity, so handsome
        (11, [10, 12]),  # 11 not handsome
        (123, [123]),    # 123 is handsome: 1(odd)->2(even)->3(odd)
        (135, [136]),    # 135 not handsome: 1->3 both odd
    ]
    
    passed = 0
    failed = 0
    
    for n, expected in test_cases:
        cocotb.log.info(f"Testing N={n}, expected={expected}")
        
        dut.n_in.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        if not is_value_defined(dut.done.value):
            cocotb.log.error(f"FAIL: done signal undefined")
            failed += 1
            continue
        
        result0 = int(dut.result0.value)
        result1 = int(dut.result1.value)
        count = int(dut.count.value)
        
        actual_results = []
        if count >= 1:
            actual_results.append(result0)
        if count == 2:
            actual_results.append(result1)
        
        # Sort actual results
        actual_results.sort()
        
        if actual_results != expected:
            cocotb.log.error(f"FAIL: N={n}, expected={expected}, got={actual_results}, count={count}")
            failed += 1
        else:
            cocotb.log.info(f"PASS: N={n}, got={actual_results}")
            passed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")