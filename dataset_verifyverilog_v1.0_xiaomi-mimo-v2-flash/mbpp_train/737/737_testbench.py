import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
DATA_WIDTH = 8
MAX_STR_LEN = 16
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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def str_to_packed(string):
    """Convert string to packed 128-bit value, bytes packed little-endian."""
    if len(string) > MAX_STR_LEN:
        raise ValueError(f"String too long: {len(string)} > {MAX_STR_LEN}")
    packed = 0
    for i, char in enumerate(string):
        ascii_val = ord(char)
        if ascii_val > 255:
            raise ValueError(f"Non-ASCII char at {i}: {char}")
        packed |= (ascii_val & 0xFF) << (8 * i)
    return packed

def check_str_expected(string):
    """Python reference implementation."""
    if not string or len(string) == 0:
        return False
    vowels = set('aeiouAEIOU')
    # First char check
    if string[0] not in vowels:
        return False
    # Rest chars check: alphanumeric or underscore
    for c in string[1:]:
        if not (c.isalnum() or c == '_'):
            return False
    return True

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_vowel_check(dut):
    # Setup clock if present
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: no clock/reset needed
        pass
    
    # Test cases from problem
    test_cases = [
        ("annie", True, "starts with vowel 'a', rest alphanumeric"),
        ("dawood", False, "starts with consonant 'd'"),
        ("Else", True, "starts with vowel 'E', rest alphanumeric"),
    ]
    
    # Additional edge cases
    edge_cases = [
        ("", False, "empty string"),
        ("u", True, "single vowel"),
        ("i", True, "single vowel"),
        ("a123", True, "vowel followed by digits"),
        ("o__", True, "vowel followed by underscores"),
        ("o-", False, "vowel followed by invalid char '-'"),
        ("A_b", True, "uppercase vowel with underscore"),
        (" ", False, "starts with space"),
        ("a\n", False, "newline invalid"),
        ("aBc123_", True, "longer valid"),
        ("az", True, "valid"),
        ("ab", True, "valid"),
        ("aa", True, "valid"),
        ("aeiou", True, "all vowels"),
        ("Uuuu", True, "uppercase start"),
    ]
    
    all_tests = test_cases + edge_cases
    passed = 0
    failed = 0
    
    for idx, (test_str, expected, desc) in enumerate(all_tests):
        cocotb.log.info(f"Test {idx+1}: '{test_str}' - {desc}")
        try:
            # Prepare input
            packed = str_to_packed(test_str)
            length = len(test_str)
            
            # Drive signals
            dut.str.value = packed
            dut.len.value = clamp_to_width(length, 4)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational: wait a bit for propagation
                await Timer(CLK_NS * 2, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            expected_val = 1 if expected else 0
            
            if result != expected_val:
                raise TestFailure(f"Expected {expected_val}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} of {len(all_tests)} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")
