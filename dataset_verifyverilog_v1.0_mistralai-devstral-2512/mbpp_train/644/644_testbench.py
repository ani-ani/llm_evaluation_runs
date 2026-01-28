import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

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

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

async def read_array(dut, name, size):
    result = []
    for i in range(size):
        if has_signal(dut, f"{name}_{i}"):
            val = getattr(dut, f"{name}_{i}").value
            result.append(safe_int(val, 0))
        elif has_signal(dut, name):
            result.append(safe_int(dut.__getattr__(name)[i].value, 0))
        else:
            result.append(0)
    return result

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_reverse_array_upto_k(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from specification
    test_cases = [
        ([1, 2, 3, 4, 5, 6, 7, 8], 4, [4, 3, 2, 1, 5, 6, 7, 8], "reverse first 4"),
        ([4, 5, 6, 7, 8, 9, 10, 11], 2, [5, 4, 6, 7, 8, 9, 10, 11], "reverse first 2"),
        ([9, 8, 7, 6, 5, 4, 3, 2], 3, [7, 8, 9, 6, 5, 4, 3, 2], "reverse first 3"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 0, [1, 2, 3, 4, 5, 6, 7, 8], "k=0 (no change)"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 8, [8, 7, 6, 5, 4, 3, 2, 1], "k=8 (reverse all)"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 1, [1, 2, 3, 4, 5, 6, 7, 8], "k=1 (no change)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_arr, k, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            await write_array(dut, 'arr', input_arr, DATA_WIDTH)
            
            if is_seq:
                dut.k.value = k
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                result = await read_array(dut, 'result', ARRAY_SIZE)
            else:
                await Timer(100, units='ns')
                result = await read_array(dut, 'result', ARRAY_SIZE)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")