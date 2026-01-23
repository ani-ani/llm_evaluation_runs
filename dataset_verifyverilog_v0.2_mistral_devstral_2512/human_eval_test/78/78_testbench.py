import cocotb
from cocotb.triggers import Timer

def hex_to_bits(hex_char):
    """Convert hex character to 4-bit binary value"""
    return int(hex_char, 16)

def hex_string_to_bits(hex_str, max_len=16):
    """Convert hex string to 128-bit value and length"""
    # Pad to max_len if needed
    padded = hex_str.ljust(max_len, '0')
    bits = 0
    for i, char in enumerate(padded):
        bits = (bits << 4) | hex_to_bits(char)
    return bits, len(hex_str)

def is_prime_hex(digit_val):
    """Check if hex digit value is prime"""
    primes = {2, 3, 5, 7, 11, 13}
    return digit_val in primes

def count_primes(hex_str):
    """Count prime hex digits in string"""
    return sum(is_prime_hex(hex_to_bits(c)) for c in hex_str)

@cocotb.test()
async def test_hex_key_basic(dut):
    """Test basic hex key counting"""
    
    # Test cases: (hex_string, expected_count)
    test_cases = [
        ("AB", 1),
        ("1077E", 2),
        ("ABED1A33", 4),
        ("2020", 2),
        ("123456789ABCDEF0", 6),
        ("112233445566778899AABBCCDDEEFF00", 12),
        ("", 0),
        ("2", 1),
        ("3", 1),
        ("5", 1),
        ("7", 1),
        ("B", 1),
        ("D", 1),
        ("1", 0),
        ("4", 0),
        ("E", 0),
        ("F", 0),
        ("2357BD", 6),  # All primes
        ("014689ACEF", 0),  # No primes
        ("2222", 4),  # Repeated primes
        ("123", 2),  # Mixed
    ]
    
    passed = 0
    total = len(test_cases)
    
    for hex_str, expected in test_cases:
        bits, length = hex_string_to_bits(hex_str)
        
        # Set inputs
        dut.hex_string.value = bits
        dut.length.value = length
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.prime_count.value)
        
        if result == expected:
            passed += 1
            print(f"PASS: '{hex_str}' -> {result} (expected {expected})")
        else:
            print(f"FAIL: '{hex_str}' -> {result} (expected {expected})")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"

@cocotb.test()
async def test_hex_key_edge_cases(dut):
    """Test edge cases and boundary conditions"""
    
    # Edge case: maximum length string
    max_string = "123456789ABCDEF0"  # 16 chars
    bits, length = hex_string_to_bits(max_string)
    dut.hex_string.value = bits
    dut.length.value = length
    await Timer(10, units='ns')
    result = int(dut.prime_count.value)
    assert result == 6, f"Max length test failed: got {result}, expected 6"
    print(f"Edge case 1 PASS: 16-char string -> {result}")
    
    # Edge case: single character
    dut.hex_string.value = 0x2
    dut.length.value = 1
    await Timer(10, units='ns')
    result = int(dut.prime_count.value)
    assert result == 1, f"Single char test failed: got {result}, expected 1"
    print(f"Edge case 2 PASS: single '2' -> {result}")
    
    # Edge case: length less than actual string bits (partial counting)
    dut.hex_string.value = 0x2357  # "2357" in bits
    dut.length.value = 2  # Only count first 2 chars: "23" -> both prime
    await Timer(10, units='ns')
    result = int(dut.prime_count.value)
    assert result == 2, f"Partial length test failed: got {result}, expected 2"
    print(f"Edge case 3 PASS: partial length -> {result}")
    
    print("All edge cases passed!")

@cocotb.test()
async def test_hex_key_all_primes(dut):
    """Test all prime hex digits individually"""
    primes = ['2', '3', '5', '7', 'B', 'D']
    
    for prime in primes:
        bits, _ = hex_string_to_bits(prime)
        dut.hex_string.value = bits
        dut.length.value = 1
        await Timer(10, units='ns')
        result = int(dut.prime_count.value)
        assert result == 1, f"Prime {prime} test failed: got {result}, expected 1"
        print(f"Prime digit '{prime}' -> {result} (PASS)")
    
    print("All individual prime tests passed!")