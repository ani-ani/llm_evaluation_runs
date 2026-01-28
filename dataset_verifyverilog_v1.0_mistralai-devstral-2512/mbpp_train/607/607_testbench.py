import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
MAX_TEXT_LEN = 64
MAX_PATTERN_LEN = 8
CLK_NS = 10
MAX_CYCLES = 200

# Helper functions

def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_string(s, max_len=MAX_TEXT_LEN):
    """Pack string into integer bits"""
    packed = 0
    for i, char in enumerate(s):
        packed |= (ord(char) & 0xFF) << (i * 8)
    return packed

def pack_array(values, bits=8):
    """Pack list of values into integer bits"""
    r = 0
    for i, v in enumerate(values):
        r |= (v & ((1 << bits) - 1)) << (i * bits)
    return r

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    """Reset DUT"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_text_array(dut, text):
    """Write text string to DUT array"""
    # Ensure text is not longer than MAX_TEXT_LEN
    text = text[:MAX_TEXT_LEN]
    
    # Individual element assignment (Critical Rule)
    for i in range(MAX_TEXT_LEN):
        if i < len(text):
            dut.text[i].value = ord(text[i]) & 0xFF
        else:
            dut.text[i].value = 0

async def write_pattern_array(dut, pattern):
    """Write pattern to DUT array"""
    pattern = pattern[:MAX_PATTERN_LEN]
    
    for i in range(MAX_PATTERN_LEN):
        if i < len(pattern):
            dut.pattern[i].value = ord(pattern[i]) & 0xFF
        else:
            dut.pattern[i].value = 0

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_find_literals(dut):
    """Test pattern matching in text"""
    
    # Setup
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        # (text, pattern, expected_start, expected_end, description)
        ('The quick brown fox jumps over the lazy dog.', 'fox', 16, 19, 'Simple literal search'),
        ('Its been a very crazy procedure right', 'crazy', 16, 21, 'Pattern with spaces'),
        ('Hardest choices required strongest will', 'will', 35, 39, 'Pattern at end'),
        ('Hello world', 'world', 6, 11, 'Simple test'),
        ('Test', 'NoMatch', 63, 64, 'No match case'),
        ('A', 'A', 0, 1, 'Single character match'),
        ('aaaa', 'aaa', 0, 3, 'Overlapping matches (first wins)'),
    ]
    
    passed = 0
    failed = 0
    
    for i, (text, pattern, exp_start, exp_end, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"  Text: '{text}' (len={len(text)})")
        cocotb.log.info(f"  Pattern: '{pattern}' (len={len(pattern)})")
        
        try:
            # Write inputs
            await write_text_array(dut, text)
            await write_pattern_array(dut, pattern)
            
            # Set lengths
            if has_signal(dut, 'text_len'):
                dut.text_len.value = len(text) & 0x3F
            if has_signal(dut, 'pattern_len'):
                dut.pattern_len.value = len(pattern) & 0x0F
            
            # Start search
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read results
            if not is_value_defined(dut.result_start.value):
                raise TestFailure("result_start undefined")
            if not is_value_defined(dut.result_end.value):
                raise TestFailure("result_end undefined")
            
            result_start = int(dut.result_start.value)
            result_end = int(dut.result_end.value)
            
            cocotb.log.info(f"  Result: start={result_start}, end={result_end}")
            
            # Validate
            if result_start != exp_start:
                raise TestFailure(f"Start index mismatch: expected {exp_start}, got {result_start}")
            if result_end != exp_end:
                raise TestFailure(f"End index mismatch: expected {exp_end}, got {result_end}")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} test(s) failed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases"""
    
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    edge_cases = [
        ('', 'a', 63, 64, 'Empty text'),
        ('abc', '', 63, 64, 'Empty pattern'),
        ('abc', 'abc', 0, 3, 'Full match'),
        ('abc', 'abcd', 63, 64, 'Pattern longer than text'),
        ('a' * 63, 'a' * 8, 0, 8, 'Max length text'),
    ]
    
    passed = 0
    failed = 0
    
    for i, (text, pattern, exp_start, exp_end, desc) in enumerate(edge_cases):
        cocotb.log.info(f"Edge Test {i+1}: {desc}")
        
        try:
            await write_text_array(dut, text)
            await write_pattern_array(dut, pattern)
            
            if has_signal(dut, 'text_len'):
                dut.text_len.value = len(text) & 0x3F
            if has_signal(dut, 'pattern_len'):
                dut.pattern_len.value = len(pattern) & 0x0F
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            result_start = int(dut.result_start.value)
            result_end = int(dut.result_end.value)
            
            if result_start != exp_start or result_end != exp_end:
                raise TestFailure(f"Expected ({exp_start}, {exp_end}), got ({result_start}, {result_end})")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} edge case(s) failed")
