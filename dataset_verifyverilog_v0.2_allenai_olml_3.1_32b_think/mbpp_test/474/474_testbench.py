import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def str_to_bytes(s):
    """Convert string to list of 8-bit bytes, pad with spaces if needed"""
    bytes_list = [ord(c) for c in s]
    # Pad to 8 characters with space (0x20)
    while len(bytes_list) < 8:
        bytes_list.append(0x20)
    return bytes_list

def bytes_to_str(bytes_list):
    """Convert list of bytes back to string"""
    return ''.join(chr(b) if 32 <= b <= 126 else '?' for b in bytes_list).rstrip()

@cocotb.test()
async def test_replace_char_basic(dut):
    """Test 1: replace 'y' with 'l' in 'polygon' -> 'pollgon'"""
    input_str = "polygon"
    old_char = "y"
    new_char = "l"
    expected = "pollgon"
    
    # Set inputs
    for i, byte in enumerate(str_to_bytes(input_str)):
        dut.str_in[i].value = byte
    dut.ch.value = ord(old_char)
    dut.newch.value = ord(new_char)
    
    # Wait for combinational logic
    await Timer(10, units='ns')
    
    # Read output
    result = ''.join(chr(int(dut.str_out[i].value)) for i in range(8)).rstrip()
    
    if result != expected:
        raise TestFailure(f"Test 1 failed: got '{result}', expected '{expected}'")
    print(f"Test 1 passed: '{input_str}' with '{old_char}'->'{new_char}' = '{result}'")

@cocotb.test()
async def test_replace_char_multiple(dut):
    """Test 2: replace 'c' with 'a' in 'character' -> 'aharaater'"""
    input_str = "character"
    old_char = "c"
    new_char = "a"
    expected = "aharaater"
    
    # Set inputs
    for i, byte in enumerate(str_to_bytes(input_str)):
        dut.str_in[i].value = byte
    dut.ch.value = ord(old_char)
    dut.newch.value = ord(new_char)
    
    await Timer(10, units='ns')
    
    result = ''.join(chr(int(dut.str_out[i].value)) for i in range(8)).rstrip()
    
    if result != expected:
        raise TestFailure(f"Test 2 failed: got '{result}', expected '{expected}'")
    print(f"Test 2 passed: '{input_str}' with '{old_char}'->'{new_char}' = '{result}'")

@cocotb.test()
async def test_replace_char_no_match(dut):
    """Test 3: replace 'l' with 'a' in 'python' -> 'python' (no change)"""
    input_str = "python"
    old_char = "l"
    new_char = "a"
    expected = "python"
    
    # Set inputs
    for i, byte in enumerate(str_to_bytes(input_str)):
        dut.str_in[i].value = byte
    dut.ch.value = ord(old_char)
    dut.newch.value = ord(new_char)
    
    await Timer(10, units='ns')
    
    result = ''.join(chr(int(dut.str_out[i].value)) for i in range(8)).rstrip()
    
    if result != expected:
        raise TestFailure(f"Test 3 failed: got '{result}', expected '{expected}'")
    print(f"Test 3 passed: '{input_str}' with '{old_char}'->'{new_char}' = '{result}'")

@cocotb.test()
async def test_replace_char_edge_cases(dut):
    """Test 4: edge cases - all same char, first/last char, space replacement"""
    # Test 4a: all same characters
    input_str = "aaaaaaaa"
    old_char = "a"
    new_char = "b"
    expected = "bbbbbbbb"
    
    for i, byte in enumerate(str_to_bytes(input_str)):
        dut.str_in[i].value = byte
    dut.ch.value = ord(old_char)
    dut.newch.value = ord(new_char)
    await Timer(10, units='ns')
    result = ''.join(chr(int(dut.str_out[i].value)) for i in range(8))
    if result != expected:
        raise TestFailure(f"Test 4a failed: got '{result}', expected '{expected}'")
    print(f"Test 4a passed: all chars replaced")
    
    # Test 4b: replace first character
    input_str = "abcd"
    old_char = "a"
    new_char = "z"
    expected = "zbcd"
    
    for i, byte in enumerate(str_to_bytes(input_str)):
        dut.str_in[i].value = byte
    dut.ch.value = ord(old_char)
    dut.newch.value = ord(new_char)
    await Timer(10, units='ns')
    result = ''.join(chr(int(dut.str_out[i].value)) for i in range(8)).rstrip()
    if result != expected:
        raise TestFailure(f"Test 4b failed: got '{result}', expected '{expected}'")
    print(f"Test 4b passed: first char replaced")
    
    # Test 4c: replace last character
    input_str = "abcde"
    old_char = "e"
    new_char = "X"
    expected = "abcdX"
    
    for i, byte in enumerate(str_to_bytes(input_str)):
        dut.str_in[i].value = byte
    dut.ch.value = ord(old_char)
    dut.newch.value = ord(new_char)
    await Timer(10, units='ns')
    result = ''.join(chr(int(dut.str_out[i].value)) for i in range(8)).rstrip()
    if result != expected:
        raise TestFailure(f"Test 4c failed: got '{result}', expected '{expected}'")
    print(f"Test 4c passed: last char replaced")

@cocotb.test()
async def test_replace_char_all_tests(dut):
    """Run all original test cases and print summary"""
    test_cases = [
        ("polygon", "y", "l", "pollgon"),
        ("character", "c", "a", "aharaater"),
        ("python", "l", "a", "python"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for input_str, old_char, new_char, expected in test_cases:
        for i, byte in enumerate(str_to_bytes(input_str)):
            dut.str_in[i].value = byte
        dut.ch.value = ord(old_char)
        dut.newch.value = ord(new_char)
        
        await Timer(10, units='ns')
        
        result = ''.join(chr(int(dut.str_out[i].value)) for i in range(8)).rstrip()
        
        if result == expected:
            passed += 1
        else:
            print(f"FAILED: '{input_str}' -> got '{result}', expected '{expected}'")
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")