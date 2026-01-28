import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH, CLK_NS, MAX_CYCLES = 16, 10, 200

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return max(0, min(max_val, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def compute_expected(a, b):
    diff = abs(a - b)
    if diff > 65535:
        diff = 65535
    s = 0
    while diff > 0:
        s += diff % 10
        diff //= 10
    return s

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    for _ in range(cycles - 1):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_digit_distance(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        (1, 2, 1, "diff 1"),
        (23, 56, 6, "diff 33"),
        (123, 256, 7, "diff 133"),
        (5000, 3000, 2, "diff 2000"),
        (9999, 1, 36, "diff 9998"),
        (0, 0, 0, "same"),
        (65535, 0, 36, "max diff"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} ({a}, {b})")
        try:
            if is_seq:
                dut.a.value = clamp_to_width(a, DATA_WIDTH)
                dut.b.value = clamp_to_width(b, DATA_WIDTH)
                await RisingEdge(dut.clk)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                dut.a.value = a
                dut.b.value = b
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
            cocotb.log.info(f"PASS: result={result}")
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
