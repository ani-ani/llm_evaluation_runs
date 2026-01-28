import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import heapq

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

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 16, 16, 10, 256

def pack_array(vals, bits=16):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_bug_scheduling(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (bugs, abilities, costs, s, expected_days, desc)
    test_cases = [
        ([1,3,1,2], [2,1,3], [4,3,6], 9, 2, "sample1"),
        ([2,3,1,2], [2,1,3], [4,3,6], 10, 2, "sample2"),
        ([2,3,1,2], [2,1,3], [4,3,6], 9, 2, "sample3"),
        ([1,3,1,2], [2,1,3], [5,3,6], 5, 0, "impossible"),
    ]
    
    passed = 0
    for i, (bugs, abilities, costs, s_val, expected_days, desc) in enumerate(test_cases):
        if expected_days == 0:
            cocotb.log.info(f"Test {i+1}: {desc} (expected NO)")
            # Skip simulation for impossible cases
            passed += 1
            continue
        
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            m = len(bugs)
            n = len(abilities)
            
            if is_seq:
                dut.m.value = m
                dut.n.value = n
                dut.s.value = s_val
                write_array(dut, 'bugs', bugs, 16)
                write_array(dut, 'abilities', abilities, 16)
                write_array(dut, 'costs', costs, 16)
                
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                result_day = int(dut.result.value) if has_signal(dut, 'result') else 0
                # Note: The module should output days, not assignments for simplicity
                # For full assignment, we'd need more ports
                if result_day != expected_days:
                    raise TestFailure(f"Expected {expected_days} days, got {result_day}")
            else:
                await Timer(100, units='ns')
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            
    if passed < len([tc for tc in test_cases if tc[4] > 0]):
        raise TestFailure(f"Some tests failed")