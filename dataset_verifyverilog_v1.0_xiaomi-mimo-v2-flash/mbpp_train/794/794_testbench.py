import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers (as per template)
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
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_string(dut, text, max_len=16):
    """Write string to dut.string_chars and dut.valid_chars arrays."""
    # Ensure string is within bounds
    text = text[:max_len]
    # Pad with nulls to max_len
    padded = text.ljust(max_len, '\0')
    
    for i in range(max_len):
        char_code = ord(padded[i]) if i < len(text) else 0
        # Check if position is valid
        valid = 1 if i < len(text) else 0
        # Write to array
        dut.string_chars[i].value = clamp_to_width(char_code, 8)
        dut.valid_chars[i].value = clamp_to_width(valid, 1)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_text_starta_endb(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from Python
    # 1. "aabbbb" -> should match (starts 'a', ends 'b')
    # 2. "aabAbbbc" -> ends 'c', should not match
    # 3. "accddbbjjj" -> starts 'a', ends 'j', should not match
    test_cases = [
        ("aabbbb", True, "simple match"),
        ("aabAbbbc", False, "ends in c"),
        ("accddbbjjj", False, "ends in j"),
        ("a", False, "single a, no b"),
        ("b", False, "starts with b, no a"),
        ("ab", True, "min match"),
        ("axxxxb", True, "internal chars ignored"),
        ("AxxxxB", False, "uppercase"),
        ("", False, "empty string"),
        ("a" + "x"*15 + "b", True, "max length match"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (text, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - '{text}'")
        try:
            await write_string(dut, text)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational, wait for propagation
                await Timer(10, units='ns')
            
            if not is_value_defined(dut.match.value):
                raise TestFailure("Match result undefined")
            
            result = int(dut.match.value) == 1
            if result != expected:
                raise TestFailure(f"Expected match={expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        if is_seq:
            await reset_dut(dut, cycles=1)
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
