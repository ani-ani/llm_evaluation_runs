import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 1000

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

def odd_position_check(nums):
    return all((nums[i] % 2) == (i % 2) for i in range(len(nums)))

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_odd_position(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        raise TestFailure("Sequential design expected")
    
    test_cases = [
        ([2,1,4,3,6,7,6,3], True, "Example 1: [2,1,4,3,6,7,6,3]"),
        ([4,1,2,0,0,0,0,0], True, "Example 2: [4,1,2] padded to 8"),
        ([1,2,3,0,0,0,0,0], False, "Example 3: [1,2,3] padded to 8"),
        ([0,0,0,0,0,0,0,0], True, "All zeros: even indices have even (0)"),
        ([1,1,1,1,1,1,1,1], False, "All ones: even indices have odd (1)"),
        ([0,1,2,3,4,5,6,7], True, "Sequential: i%2 == i%2"),
        ([255,255,255,255,255,255,255,255], False, "All 255 (odd): even indices wrong"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        # Pad to 8 elements
        padded = (inp + [0] * ARRAY_SIZE)[:ARRAY_SIZE]
        
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            await write_array(dut, 'arr', padded, DATA_WIDTH)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != int(exp):
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed!")
