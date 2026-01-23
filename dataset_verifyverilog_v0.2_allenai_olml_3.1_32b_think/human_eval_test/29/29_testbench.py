import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

# Helper function to convert string to 64-bit packed representation
def str_to_64bit(s):
    """Pack an 8-character string into 64 bits (big-endian: first char in MSB)"""
    result = 0
    s_padded = s.ljust(8, '\0')  # Pad to 8 chars
    for i, ch in enumerate(s_padded[:8]):
        result |= (ord(ch) << (56 - i*8))
    return result

# Helper to convert 64-bit back to string for debugging
def bit64_to_str(val):
    s = ''
    for i in range(8):
        byte = (val >> (56 - i*8)) & 0xFF
        if byte == 0:
            break
        s += chr(byte)
    return s

@cocotb.test()
async def test_filter_by_prefix(dut):
    """Test filter_by_prefix module with various cases"""
    
    # Test case 1: Empty input (all zeros) -> 0 matches
    dut.strings = [0] * 8
    dut.prefix = 0
    dut.prefix_len = 0
    
    await Timer(10, units='ns')
    
    match_count = int(dut.match_count)
    if match_count != 0:
        raise TestFailure(f"Test 1 failed: Expected 0 matches, got {match_count}")
    print(f"Test 1 passed: Empty input -> 0 matches")
    
    # Test case 2: Filter strings starting with 'x' (ASCII 120)
    # Input strings: ['xxx', 'asd', 'xxy', 'john doe', 'xxxAAA', 'xxx']
    # In our 8-char format: ['xxx     ', 'asd     ', 'xxy     ', 'john doe', 'xxxAAA  ', 'xxx     ']
    strings_input = [
        str_to_64bit('xxx     '),
        str_to_64bit('asd     '),
        str_to_64bit('xxy     '),
        str_to_64bit('john doe'),
        str_to_64bit('xxxAAA  '),
        str_to_64bit('xxx     '),
        0,  # unused
        0   # unused
    ]
    
    dut.strings = strings_input
    dut.prefix = str_to_64bit('x       ')  # Single 'x' prefix
    dut.prefix_len = 1
    
    await Timer(10, units='ns')
    
    match_count = int(dut.match_count)
    if match_count != 3:
        raise TestFailure(f"Test 2 failed: Expected 3 matches, got {match_count}")
    
    # Check matches
    expected_matches = ['xxx', 'xxxAAA', 'xxx']
    for i, expected in enumerate(expected_matches):
        actual = bit64_to_str(int(dut.matches[i]))
        if actual != expected:
            raise TestFailure(f"Test 2 failed: Match {i} expected '{expected}', got '{actual}'")
    
    print(f"Test 2 passed: Found {match_count} matches")
    
    # Test case 3: Multi-character prefix 'abc'
    strings_input_3 = [
        str_to_64bit('abc123  '),
        str_to_64bit('abx     '),
        str_to_64bit('abc456  '),
        str_to_64bit('xyz     '),
        0, 0, 0, 0
    ]
    
    dut.strings = strings_input_3
    dut.prefix = str_to_64bit('abc     ')  # 'abc' prefix
    dut.prefix_len = 3
    
    await Timer(10, units='ns')
    
    match_count = int(dut.match_count)
    if match_count != 2:
        raise TestFailure(f"Test 3 failed: Expected 2 matches, got {match_count}")
    
    print(f"Test 3 passed: Multi-char prefix works, {match_count} matches")
    
    # Test case 4: Prefix longer than strings
    strings_input_4 = [
        str_to_64bit('a        '),
        str_to_64bit('ab       '),
        str_to_64bit('abc      '),
        0, 0, 0, 0, 0
    ]
    
    dut.strings = strings_input_4
    dut.prefix = str_to_64bit('abcd    ')  # 4 chars
    dut.prefix_len = 4
    
    await Timer(10, units='ns')
    
    match_count = int(dut.match_count)
    if match_count != 0:
        raise TestFailure(f"Test 4 failed: Expected 0 matches (prefix too long), got {match_count}")
    
    print(f"Test 4 passed: Long prefix handled correctly")
    
    # Test case 5: All strings match
    strings_input_5 = [
        str_to_64bit('test1   '),
        str_to_64bit('test2   '),
        str_to_64bit('test3   '),
        0, 0, 0, 0, 0
    ]
    
    dut.strings = strings_input_5
    dut.prefix = str_to_64bit('test    ')  # 4 chars
    dut.prefix_len = 4
    
    await Timer(10, units='ns')
    
    match_count = int(dut.match_count)
    if match_count != 3:
        raise TestFailure(f"Test 5 failed: Expected 3 matches, got {match_count}")
    
    print(f"Test 5 passed: All strings matched, count={match_count}")
    
    print("
=== Summary ===")
    print("All 5 tests passed!")
