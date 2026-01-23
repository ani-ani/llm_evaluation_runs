import cocotb
from cocotb.triggers import Timer
import random

def str_to_bytes(s, max_len=16):
    """Convert string to 128-bit packed bytes with length"""
    # Truncate to max_len
    s = s[:max_len]
    length = len(s)
    
    # Pack into integer (128-bit)
    packed = 0
    for i, char in enumerate(s):
        # Each character is 8 bits
        packed |= (ord(char) << (8 * i))
    
    return packed, length

def normalize_char(c):
    """Convert to uppercase if lowercase"""
    if 0x61 <= c <= 0x7A:  # 'a' to 'z'
        return c - 0x20
    return c

def count_distinct_python(s):
    """Reference implementation for test cases"""
    if not s:
        return 0
    
    normalized = set()
    for char in s:
        c = ord(char)
        if 0x61 <= c <= 0x7A:
            c -= 0x20
        normalized.add(c)
    
    return len(normalized)

@cocotb.test()
async def test_count_distinct_characters(dut):
    """Test distinct character counting with case insensitivity"""
    
    print("
=== Testing count_distinct_characters ===")
    
    test_cases = [
        "",  # Empty string
        "abcde",  # 5 distinct
        "abcde" + "cade" + "CADE",  # Should be 5: a, b, c, d, e
        "aaaaAAAAaaaa",  # 1 distinct: A/a
        "Jerry jERRY JeRRRY",  # Should be 5: J, E, R, Y, space
        "xyzXYZ",  # 3 distinct: X, Y, Z
        "AbCdEfGh",  # 8 distinct
        "AaBbCcDd",  # 4 distinct: A, B, C, D
        "ZZZZ",  # 1 distinct
        "AbCdEfGhIjKlMnOp",  # 16 distinct, should be 16 but truncated to 16 chars
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, test_str in enumerate(test_cases):
        # Convert to Verilog format
        packed, length = str_to_bytes(test_str)
        expected = count_distinct_python(test_str)
        
        # Set inputs
        dut.char_array.value = packed
        dut.length.value = length
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read output
        result = dut.distinct_count.value
        result_int = int(result)
        
        # Verify
        if result_int == expected:
            print(f"Test {i+1}: PASS | Input: '{test_str}' (len={length}) | Expected: {expected}, Got: {result_int}")
            passed += 1
        else:
            print(f"Test {i+1}: FAIL | Input: '{test_str}' (len={length}) | Expected: {expected}, Got: {result_int}")
    
    # Additional edge case: all lowercase
    dut.char_array.value = 0x6162636465666768696A6B6C6D6E6F70  # 'abcdefghijklmnop'
    dut.length.value = 16
    await Timer(10, units='ns')
    result = int(dut.distinct_count.value)
    expected = 16
    if result == expected:
        print(f"Test 11: PASS | Input: 16 unique lowercase | Expected: {expected}, Got: {result}")
        passed += 1
    else:
        print(f"Test 11: FAIL | Input: 16 unique lowercase | Expected: {expected}, Got: {result}")
    total += 1
    
    # Mixed case identical
    dut.char_array.value = 0x41614262436344644565466647674868  # 'AaBbCcDdEeFfGgHh'
    dut.length.value = 16
    await Timer(10, units='ns')
    result = int(dut.distinct_count.value)
    expected = 8
    if result == expected:
        print(f"Test 12: PASS | Input: 8 pairs of upper/lower | Expected: {expected}, Got: {result}")
        passed += 1
    else:
        print(f"Test 12: FAIL | Input: 8 pairs of upper/lower | Expected: {expected}, Got: {result}")
    total += 1
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"
