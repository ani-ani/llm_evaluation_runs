import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    val = int(v)
    if val < 0: return 0
    if val > max_val: return max_val
    return val

def char_to_idx(c):
    return ord(c) - ord('a')

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done signal after {max_cycles} cycles")

def pack_string_array(dut, signal_name, string_val, max_len=16):
    # Maps string to 16x5bit array inputs
    # If string is longer than 16, we only take first 16 chars
    chars = string_val[:max_len]
    for i in range(max_len):
        if i < len(chars):
            val = char_to_idx(chars[i])
        else:
            val = 0
        # Access individual array elements
        # Construct the signal object name based on Verilog convention
        # Typically: dut.s_0, dut.s_1, etc. OR dut.s[i]
        # We will try to handle dut.s[i] if available, else dut.s_i
        try:
            getattr(dut, signal_name)[i].value = clamp_to_width(val, 5)
        except AttributeError:
            # Fallback for flattened names like s_0
            sub_sig = f"{signal_name}_{i}"
            if has_signal(dut, sub_sig):
                getattr(dut, sub_sig).value = clamp_to_width(val, 5)
            else:
                raise TestFailure(f"Signal {signal_name}[{i}] or {sub_sig} not found")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_merge_check(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (s, s1, s2, expected_valid)
    test_cases = [
        ("aabcad", "aba", "acd", True),
        ("aabcad", "acb", "aad", False),
        ("aabcad", "acb", "acd", False),
        ("abc", "ac", "b", True),
        ("abc", "ab", "c", True),
        ("abc", "abc", "", True),
        ("abc", "", "abc", True),
        ("abc", "d", "e", False),
    ]

    for i, (s, s1, s2, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: s='{s}', s1='{s1}', s2='{s2}' (Exp: {expected})")
        
        # Set inputs
        pack_string_array(dut, 's', s)
        pack_string_array(dut, 's1', s1)
        pack_string_array(dut, 's2', s2)
        
        if has_signal(dut, 'len_s'):
            dut.len_s.value = len(s)
        if has_signal(dut, 'len_s1'):
            dut.len_s1.value = len(s1)
        if has_signal(dut, 'len_s2'):
            dut.len_s2.value = len(s2)
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        if not is_value_defined(dut.valid.value):
            raise TestFailure(f"Test {i+1}: Result 'valid' is undefined")
        
        result = int(dut.valid.value) == 1
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        await RisingEdge(dut.clk)
