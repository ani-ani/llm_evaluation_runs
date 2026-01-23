import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def str_to_hex(s):
    """Convert string to packed hex representation (16 chars, 8 bits each)"""
    result = 0
    for i, char in enumerate(s):
        result |= ord(char) << (8 * i)
    return result

def hex_to_packed_str(hex_val):
    """Convert packed hex back to string for comparison"""
    s = ""
    for i in range(16):
        byte = (hex_val >> (8 * i)) & 0xFF
        if byte != 0:
            s += chr(byte)
    return s

@cocotb.test()
async def test_longest_repeated_substring(dut):
    """Test the longest repeated substring module"""
    
    # Test cases: (input_string, expected_output_string)
    test_cases = [
        ("abcefgabc", "abc"),
        ("abcbabcba", "abcba"),
        ("aaaa", "aaa"),
        ("bbcaadbbeaa", "aa"),
        ("abcabc", "abc"),
        ("banana", "ana"),
        ("aaaaa", "aaaa"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        # Prepare inputs
        dut.char_array.value = str_to_hex(input_str)
        dut.valid_len.value = len(input_str)
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read outputs
        result_hex = int(dut.result_string.value)
        result_len = int(dut.result_len.value)
        
        # Convert result
        result_str = hex_to_packed_str(result_hex)
        
        # Trim result to reported length
        result_str = result_str[:result_len]
        
        # Verify
        if result_str == expected_str:
            passed += 1
            print(f"Test {i+1}: PASS - Input: '{input_str}' -> Output: '{result_str}'")
        else:
            print(f"Test {i+1}: FAIL - Input: '{input_str}'")
            print(f"  Expected: '{expected_str}' (len={len(expected_str)})")
            print(f"  Got:      '{result_str}' (len={result_len})")
            print(f"  Raw hex result: {hex(result_hex)}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")