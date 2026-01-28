import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 8
OUTPUT_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 100

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
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    min_val = -(1 << bits)
    if v > max_val:
        return max_val
    if v < min_val:
        return min_val
    return v

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def compute_directrix(a, b, c):
    # Python version from tests
    directrix = int(c - ((b * b) + 1) * 4 * a)
    return directrix

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_parabola_directrix(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (5, 3, 2, -198, "Test 1"),
        (9, 8, 4, -2336, "Test 2"),
        (2, 4, 6, -130, "Test 3")
    ]
    
    passed = 0
    failed = 0
    
    for i, (a_val, b_val, c_val, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - a={a_val}, b={b_val}, c={c_val}, expected={expected}")
        try:
            # Set inputs
            dut.a.value = from_signed(a_val, DATA_WIDTH)
            dut.b.value = from_signed(b_val, DATA_WIDTH)
            dut.c.value = from_signed(c_val, DATA_WIDTH)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            result_raw = int(dut.result.value)
            # Convert from signed representation if needed
            result = to_signed(result_raw, OUTPUT_WIDTH)
            
            cocotb.log.info(f"  Result: {result}")
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed")