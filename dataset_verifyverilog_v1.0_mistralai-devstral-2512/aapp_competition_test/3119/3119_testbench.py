import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 16
MAX_NOTES = 16
MAX_PHRASES = 16
CLK_NS = 10
MAX_CYCLES = 1500

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_notes(dut, notes):
    for i, v in enumerate(notes[:MAX_NOTES]):
        dut.notes[i].value = clamp_to_width(v, DATA_WIDTH)
    dut.num_notes.value = len(notes) if len(notes) <= MAX_NOTES else MAX_NOTES

async def write_phrases(dut, phrases):
    for i, (s, e) in enumerate(phrases[:MAX_PHRASES]):
        dut.phrases_start[i].value = clamp_to_width(s, DATA_WIDTH)
        dut.phrases_end[i].value = clamp_to_width(e, DATA_WIDTH)
    dut.num_phrases.value = len(phrases) if len(phrases) <= MAX_PHRASES else MAX_PHRASES

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_guitar_hero(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)

    # Test cases: (notes_times, phrases_list, expected_score, desc)
    test_cases = [
        ([0, 10, 20], [(0, 10)], 4, "Sample 1"),
        ([0, 10, 20, 26, 40, 50], [(0, 40)], 9, "Sample 2"),
        ([0,10,20,30,40,50,60,70,80,90], [(0,40),(70,80)], 14, "Sample 3"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (notes, phrases, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            await write_notes(dut, notes)
            await write_phrases(dut, phrases)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(1000, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
