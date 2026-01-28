import cocotb
from cocotb.triggers import Timer, RisingEdge, Join
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
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

# Global config
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 100

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_strings(dut, s1, s2):
    # Pad strings to 16 chars with null (or space) if shorter
    # Assuming 'a' (0x61) as padding char if needed, but inputs are fixed size in spec
    # We'll just fill provided chars and zero-pad the rest (assuming 0 is safe or ignored)
    
    # In the spec, we defined individual inputs str_a_0...str_a_15
    # Check if they exist, otherwise try packed input
    
    if has_signal(dut, 'str_a_0'):
        for i in range(16):
            val = ord(s1[i]) if i < len(s1) else 0
            getattr(dut, f'str_a_{i}').value = clamp_to_width(val, DATA_WIDTH)
        for i in range(16):
            val = ord(s2[i]) if i < len(s2) else 0
            getattr(dut, f'str_b_{i}').value = clamp_to_width(val, DATA_WIDTH)
    elif has_signal(dut, 'str_a'):
        # Packed array assumption
        val_a = 0
        val_b = 0
        for i in range(16):
            char_a = ord(s1[i]) if i < len(s1) else 0
            char_b = ord(s2[i]) if i < len(s2) else 0
            val_a |= (char_a & 0xFF) << (i * 8)
            val_b |= (char_b & 0xFF) << (i * 8)
        dut.str_a.value = val_a
        dut.str_b.value = val_b
    else:
        # Try array access style (dut.str_a[i] if it's a bus of arrays)
        try:
            for i in range(16):
                val = ord(s1[i]) if i < len(s1) else 0
                dut.str_a[i].value = clamp_to_width(val, DATA_WIDTH)
            for i in range(16):
                val = ord(s2[i]) if i < len(s2) else 0
                dut.str_b[i].value = clamp_to_width(val, DATA_WIDTH)
        except Exception as e:
            print(f"Warning: Could not assign strings: {e}")

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_string_equivalence(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test Cases
    # 1. Exact match
    # 2. Equivalent but swapped halves
    # 3. Not equivalent
    # 4. Odd length (if supported, but spec says power of 2/16) -> using padded
    
    test_cases = [
        ("aaba", "abaa", "YES", "Sample 1"),
        ("aabb", "abab", "NO", "Sample 2"),
        ("abcd", "abcd", "YES", "Identical"),
        ("abcd", "bacd", "NO", "Diff first char"),
        ("abcd", "abdc", "NO", "Diff second half"),
        ("1234", "1234", "YES", "Numeric identical"),
        ("aaaa", "aaaa", "YES", "All same"),
        ("abcd", "bacd", "NO", "No match"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (s1, s2, expected_str, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} ({s1}, {s2})")
        
        # Pad to 16 chars
        s1_pad = s1.ljust(16, 'a')
        s2_pad = s2.ljust(16, 'a')
        
        # Write inputs
        await write_strings(dut, s1_pad, s2_pad)
        
        # Trigger
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            # Combinational circuit (should be stable after a short delay)
            await Timer(100, units='ns')
        
        # Check result
        if not is_value_defined(dut.is_equivalent.value):
            cocotb.log.error(f"Test {i+1} FAIL: Result undefined")
            failed += 1
            continue
            
        result_bit = int(dut.is_equivalent.value)
        expected_bit = 1 if expected_str == "YES" else 0
        
        if result_bit == expected_bit:
            cocotb.log.info(f"Test {i+1} PASS")
            passed += 1
        else:
            cocotb.log.error(f"Test {i+1} FAIL: Expected {expected_str} ({expected_bit}), got {result_bit}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
