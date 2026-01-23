import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper function to check if value is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper function to convert Python string to 128-bit packed integer
def pack_string(s):
    """Pack a string into a 128-bit integer (16 bytes, little-endian)."""
    if len(s) > 16:
        raise ValueError("String exceeds maximum length of 16 bytes")
    packed = 0
    for i, char in enumerate(s):
        packed |= (ord(char) << (8 * i))
    return packed

# Helper function to check primality for lengths 0-16
def is_prime_length(length):
    """Return True if length is prime (2, 3, 5, 7, 11, 13)."""
    primes = {2, 3, 5, 7, 11, 13}
    return length in primes

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_prime_length(dut):
    """Test the prime_length module with various string lengths."""
    
    # Test cases: (string, expected_result)
    test_cases = [
        ('Hello', True),
        ('abcdcba', True),
        ('kittens', True),
        ('orange', False),
        ('wow', True),
        ('world', True),
        ('MadaM', True),
        ('Wow', True),
        ('', False),
        ('HI', True),
        ('go', True),
        ('gogo', False),
        ('aaaaaaaaaaaaaaa', False),  # 15 chars
        ('Madam', True),
        ('M', False),
        ('0', False),
        ('aaaa', False),  # 4 chars
        ('aaaaaaa', True),  # 7 chars
        ('aaaaaaaaaaaa', False),  # 12 chars
        ('aaaaaaaaaaaaa', True),  # 13 chars
    ]
    
    passed = 0
    failed = 0
    
    for test_str, expected in test_cases:
        # Pack the string into 128 bits
        packed = pack_string(test_str)
        length = len(test_str)
        
        # Assign inputs
        dut.string_data.value = packed
        dut.string_len.value = length
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Check if output is defined
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Test '{test_str}': Output is undefined (X/Z)")
            failed += 1
            continue
        
        # Get result
        result = bool(int(dut.result.value))
        
        # Verify
        if result == expected:
            passed += 1
            dut._log.info(f"Test '{test_str}': PASSED (len={length}, result={result})")
        else:
            failed += 1
            dut._log.error(f"Test '{test_str}': FAILED (len={length}, expected {expected}, got {result})")
    
    # Summary
    total = passed + failed
    dut._log.info(f"\n=== SUMMARY: {passed}/{total} tests passed ===")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {total} tests failed")