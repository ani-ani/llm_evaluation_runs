import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def char_to_ascii(c):
    """Convert character to ASCII hex value"""
    return ord(c)

def string_to_8chars(s):
    """Pad or truncate string to exactly 8 characters, return list of ASCII values"""
    padded = s.ljust(8, '\0')[:8]
    return [char_to_ascii(c) for c in padded]

def max_run_uppercase_python(s):
    """Python reference implementation"""
    cnt = 0
    res = 0
    for idx in range(len(s)):
        if s[idx].isupper():
            cnt += 1
        else:
            if cnt > res:
                res = cnt
            cnt = 0
    if len(s) > 0 and s[-1].isupper():
        if cnt > res:
            res = cnt
    return res

@cocotb.test()
async def test_max_run_uppercase(dut):
    """Test maximum uppercase run detection"""
    
    # Test cases: (input_string, expected_run)
    test_cases = [
        ('GeMKSForGERksISBESt', 5),  # Test 1
        ('PrECIOusMOVemENTSYT', 6),  # Test 2
        ('GooGLEFluTTER', 4),        # Test 3
        ('abc', 0),                  # No uppercase
        ('ABC', 3),                  # All uppercase
        ('aBcDe', 1),                # Single uppercase
        ('', 0),                     # Empty string (all nulls)
        ('AAAAAAAA', 8),             # Maximum possible run
        ('AaAaAaAa', 1),             # Alternating
    ]
    
    passed = 0
    total = len(test_cases)
    
    print(f"
Running {total} test cases...")
    
    for input_str, expected in test_cases:
        # Convert string to ASCII values
        chars = string_to_8chars(input_str)
        
        # Set inputs
        dut.char0.value = chars[0]
        dut.char1.value = chars[1]
        dut.char2.value = chars[2]
        dut.char3.value = chars[3]
        dut.char4.value = chars[4]
        dut.char5.value = chars[5]
        dut.char6.value = chars[6]
        dut.char7.value = chars[7]
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.max_run.value)
        
        # Verify
        if result == expected:
            print(f"  PASS: '{input_str}' -> {result} (expected {expected})")
            passed += 1
        else:
            print(f"  FAIL: '{input_str}' -> {result} (expected {expected})")
            print(f"    Input chars: {[hex(c) for c in chars]}")
            raise TestFailure(f"Test failed for '{input_str}': got {result}, expected {expected}")
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    assert passed == total, f"Expected all {total} tests to pass, but only {passed} passed"
