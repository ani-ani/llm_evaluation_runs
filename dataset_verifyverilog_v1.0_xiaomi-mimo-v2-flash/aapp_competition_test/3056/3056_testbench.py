import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import struct

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Pattern to packed data
async def write_pattern(dut, pattern_str):
    # pattern_data is 128-bit (16x8-bit)
    # Pack into integer
    packed = 0
    for i, ch in enumerate(pattern_str):
        if i >= 16:
            break
        packed |= (ord(ch) & 0xFF) << (i * 8)
    dut.pattern_data.value = packed
    dut.pattern_len.value = len(pattern_str)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_walks(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        ("P*P", 6, "P*P"),
        ("L*R", 25, "L*R"),
        ("**", 33, "**"),
        ("LLLLLRRRRRLLLLLRRRRRLLLLLRRRRRLLLLL", 35400942560, "Long pattern")
    ]
    
    passed = 0
    failed = 0
    
    for pattern, expected, desc in test_cases:
        cocotb.log.info(f"Testing: {desc} (pattern='{pattern}')")
        try:
            await write_pattern(dut, pattern)
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"PASS: Result {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")
    
    cocotb.log.info(f"All {passed} tests passed")
