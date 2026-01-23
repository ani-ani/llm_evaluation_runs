import cocotb
from cocotb.triggers import Timer
import random

def to_ascii(char):
    """Convert character to ASCII value"""
    return ord(char)

def count_uppercase_in_string(s):
    """Count uppercase characters in Python string"""
    return sum(1 for c in s if c.isupper())

@cocotb.test()
async def test_uppercase_counter(dut):
    """Test uppercase counter with various string inputs"""
    
    # Test cases: (string, expected_count)
    test_cases = [
        ('PYthon', 1),  # Original test case 1 - only 6 chars used
        ('BigData', 1),  # Original test case 2 - 7 chars
        ('program', 0),  # Original test case 3 - 7 chars
        ('ABC', 3),      # All uppercase
        ('abc', 0),      # All lowercase
        ('AbCd', 4),     # Mixed, all uppercase
        ('aBcDeFg', 2),  # 2 uppercase in 7 chars
        ('TEST123', 4),  # Uppercase letters only
    ]
    
    passed = 0
    total = len(test_cases)
    
    print("
=== Uppercase Counter Test Results ===")
    
    for test_idx, (test_str, expected) in enumerate(test_cases, 1):
        # Prepare input - pad to 8 chars, track valid length
        char_array = [0] * 8
        valid_len = min(len(test_str), 8)
        
        for i in range(valid_len):
            char_array[i] = to_ascii(test_str[i])
        
        # Set inputs
        for i in range(8):
            dut.char_array[i].value = char_array[i]
        dut.valid_length.value = valid_len
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.count.value)
        
        # Check result
        status = "PASS" if result == expected else "FAIL"
        print(f"Test {test_idx}: '{test_str}' (len={valid_len}) -> Expected: {expected}, Got: {result} [{status}]")
        
        assert result == expected, f"Test {test_idx} failed: '{test_str}' expected {expected}, got {result}"
        passed += 1
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    print(f"
All {passed} tests passed successfully!
")

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases for boundary conditions"""
    
    edge_cases = [
        ('', 0, 0),  # Empty string
        ('A', 1, 1),  # Single uppercase
        ('z', 0, 1),  # Single lowercase
        ('AAAAAAAA', 8, 8),  # Full array, all uppercase
        ('aaaaaaaa', 0, 8),  # Full array, all lowercase
        ('@', 0, 1),  # Character before 'A'
        ('[', 0, 1),  # Character after 'Z'
        ('A[', 1, 2),  # Mix with non-letters
    ]
    
    passed = 0
    total = len(edge_cases)
    
    print("
=== Edge Case Test Results ===")
    
    for test_idx, (test_str, expected, valid_len) in enumerate(edge_cases, 1):
        char_array = [0] * 8
        actual_len = min(len(test_str), valid_len)
        
        for i in range(actual_len):
            char_array[i] = to_ascii(test_str[i])
        
        # Set inputs
        for i in range(8):
            dut.char_array[i].value = char_array[i]
        dut.valid_length.value = actual_len
        
        await Timer(10, units='ns')
        
        result = int(dut.count.value)
        
        status = "PASS" if result == expected else "FAIL"
        print(f"Edge {test_idx}: '{test_str}' (len={actual_len}) -> Expected: {expected}, Got: {result} [{status}]")
        
        assert result == expected, f"Edge test {test_idx} failed: expected {expected}, got {result}"
        passed += 1
    
    print(f"
=== Summary: {passed}/{total} edge tests passed ===")
    print(f"
All {passed} edge tests passed successfully!
")