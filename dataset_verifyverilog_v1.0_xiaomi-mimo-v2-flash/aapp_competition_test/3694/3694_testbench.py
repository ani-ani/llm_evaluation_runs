import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 32, 16, 10, 1000

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

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

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

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_stones_game(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_array, expected_result, description)
    # result: 0=cslnb, 1=sjfnb
    test_cases = [
        ([0], 0, "n=1, a=[0]"),
        ([1, 0], 0, "n=2, a=[1,0]"),
        ([2, 2], 1, "n=2, a=[2,2]"),
        ([2, 3, 1], 1, "n=3, a=[2,3,1]"),
        ([3, 3, 3], 0, "n=3, a=[3,3,3]"),
        ([4, 4, 4], 0, "n=3, a=[4,4,4]"),
        ([2, 2, 4, 4], 0, "n=4, a=[2,2,4,4]"),
        ([0, 5, 6, 7, 8], 1, "n=5, a=[0,5,6,7,8]"),
        ([0, 0, 1, 5, 8], 0, "n=5, a=[0,0,1,5,8]"),
        ([1], 1, "n=1, a=[1]"),
        ([2], 0, "n=1, a=[2]"),
        ([0, 0], 0, "n=2, a=[0,0]"),
        ([0, 1], 0, "n=2, a=[0,1]"),
        ([1, 1], 1, "n=2, a=[1,1]"),
        ([2, 0], 0, "n=2, a=[2,0]"),
        ([2, 1], 1, "n=2, a=[2,1]"),
        ([3, 3], 0, "n=2, a=[3,3]"),
        ([2, 3, 3], 1, "n=3, a=[2,3,3]"),
        ([0, 1, 1], 0, "n=3, a=[0,1,1]"),
        ([0, 2, 2], 0, "n=3, a=[0,2,2]"),
        ([3, 3, 2], 0, "n=3, a=[3,3,2]"),
        ([5, 5, 4], 0, "n=3, a=[5,5,4]"),
        ([0, 1, 1, 5], 0, "n=4, a=[0,1,1,5]"),
        ([1, 2, 2, 4], 1, "n=4, a=[1,2,2,4]"),
        ([4, 5, 5, 8], 1, "n=4, a=[4,5,5,8]"),
        ([0, 0, 2, 4], 0, "n=4, a=[0,0,2,4]"),
        ([0, 1, 2, 4], 1, "n=4, a=[0,1,2,4]"),
        ([0, 5, 6, 6], 0, "n=4, a=[0,5,6,6]"),
        ([1, 1, 2, 2, 5], 0, "n=5, a=[1,1,2,2,5]"),
        ([1, 5, 8, 13, 50, 150, 151, 151, 200, 255], 0, "n=10, a=[1,5,8,13,50,150,151,151,200,255]"),
        ([5, 5, 5, 5, 5], 0, "n=5, a=[5,5,5,5,5]"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            n = len(inp)
            if n > ARRAY_SIZE:
                cocotb.log.warning(f"Test case {i+1} has n={n} > ARRAY_SIZE={ARRAY_SIZE}, skipping")
                continue
            
            if is_seq:
                # Write inputs
                if has_signal(dut, 'len'):
                    dut.len.value = n
                
                # Write array - individual assignment
                for j in range(ARRAY_SIZE):
                    if j < n:
                        dut.arr[j].value = clamp_to_width(inp[j], DATA_WIDTH)
                    else:
                        dut.arr[j].value = 0
                
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational
                for j in range(ARRAY_SIZE):
                    if j < n:
                        dut.arr[j].value = clamp_to_width(inp[j], DATA_WIDTH)
                    else:
                        dut.arr[j].value = 0
                if has_signal(dut, 'len'):
                    dut.len.value = n
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            # Map to expected format: 0 for cslnb, 1 for sjfnb
            expected_val = exp
            
            if result != expected_val:
                raise TestFailure(f"Expected {expected_val}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}")
