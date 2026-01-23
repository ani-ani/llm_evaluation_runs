import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def python_reference(text):
    """Python reference implementation for palindrome check."""
    return text == text[::-1]

def string_to_bytes(text, max_len=8):
    """Convert string to array of bytes (ASCII values), right-padded with 0."""
    bytes_list = [ord(c) for c in text]
    while len(bytes_list) < max_len:
        bytes_list.append(0)
    return bytes_list

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_basic_palindromes(dut):
    """Test basic palindrome cases."""
    
    test_cases = [
        ("", True),
        ("a", True),
        ("aba", True),
        ("aaaaa", True),
        ("abba", True),
        ("abcba", True),
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Starting {total} basic palindrome tests...")
    
    for i, (text, expected) in enumerate(test_cases):
        byte_array = string_to_bytes(text)
        actual_length = len(text)
        
        # Set individual character inputs
        dut.str_0.value = byte_array[0]
        dut.str_1.value = byte_array[1]
        dut.str_2.value = byte_array[2]
        dut.str_3.value = byte_array[3]
        dut.str_4.value = byte_array[4]
        dut.str_5.value = byte_array[5]
        dut.str_6.value = byte_array[6]
        dut.str_7.value = byte_array[7]
        dut.length.value = actual_length
        
        # Wait for combinational logic to settle
        await Timer(50, units='ns')
        
        # Check output is defined
        if not is_value_defined(dut.is_palindrome.value):
            raise TestFailure(f"Test {i} ({text!r}): Output undefined")
        
        result = int(dut.is_palindrome.value)
        expected_int = 1 if expected else 0
        
        if result != expected_int:
            raise TestFailure(
                f"Test {i} ({text!r}): Expected {expected_int}, got {result}"
            )
        
        passed += 1
        dut._log.info(f"Test {i} ({text!r}): PASSED")
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_non_palindromes(dut):
    """Test non-palindrome cases."""
    
    test_cases = [
        ("zbcd", False),
        ("xywyz", False),
        ("xywzx", False),
        ("abca", False),
        ("abcde", False),
        ("abcdefgh", False),
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Starting {total} non-palindrome tests...")
    
    for i, (text, expected) in enumerate(test_cases):
        byte_array = string_to_bytes(text)
        actual_length = len(text)
        
        dut.str_0.value = byte_array[0]
        dut.str_1.value = byte_array[1]
        dut.str_2.value = byte_array[2]
        dut.str_3.value = byte_array[3]
        dut.str_4.value = byte_array[4]
        dut.str_5.value = byte_array[5]
        dut.str_6.value = byte_array[6]
        dut.str_7.value = byte_array[7]
        dut.length.value = actual_length
        
        await Timer(50, units='ns')
        
        if not is_value_defined(dut.is_palindrome.value):
            raise TestFailure(f"Test {i} ({text!r}): Output undefined")
        
        result = int(dut.is_palindrome.value)
        expected_int = 1 if expected else 0
        
        if result != expected_int:
            raise TestFailure(
                f"Test {i} ({text!r}): Expected {expected_int}, got {result}"
            )
        
        passed += 1
        dut._log.info(f"Test {i} ({text!r}): PASSED")
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_all_lengths_same_char(dut):
    """Test all possible lengths with same character."""
    
    passed = 0
    total = 9  # Lengths 0-8
    
    dut._log.info(f"Starting {total} same-character tests...")
    
    for length in range(total):
        text = "a" * length
        byte_array = string_to_bytes(text)
        
        dut.str_0.value = byte_array[0]
        dut.str_1.value = byte_array[1]
        dut.str_2.value = byte_array[2]
        dut.str_3.value = byte_array[3]
        dut.str_4.value = byte_array[4]
        dut.str_5.value = byte_array[5]
        dut.str_6.value = byte_array[6]
        dut.str_7.value = byte_array[7]
        dut.length.value = length
        
        await Timer(50, units='ns')
        
        if not is_value_defined(dut.is_palindrome.value):
            raise TestFailure(f"Length {length}: Output undefined")
        
        result = int(dut.is_palindrome.value)
        expected = 1
        
        if result != expected:
            raise TestFailure(
                f"Length {length}: Expected {expected}, got {result}"
            )
        
        passed += 1
        dut._log.info(f"Length {length}: PASSED")
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_mixed_edge_cases(dut):
    """Test edge cases with special patterns."""
    
    test_cases = [
        ("  ", True),        # Two spaces
        ("a b a", True),     # Palindrome with spaces
        ("123321", True),    # Numeric palindrome
        ("xywyx", True),     # 5 char palindrome
        ("abccba", True),    # 6 char palindrome
        ("a" * 8, True),     # Max length palindrome
        ("abcdefgh", False), # Max length non-palindrome
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Starting {total} edge case tests...")
    
    for i, (text, expected) in enumerate(test_cases):
        byte_array = string_to_bytes(text)
        actual_length = len(text)
        
        dut.str_0.value = byte_array[0]
        dut.str_1.value = byte_array[1]
        dut.str_2.value = byte_array[2]
        dut.str_3.value = byte_array[3]
        dut.str_4.value = byte_array[4]
        dut.str_5.value = byte_array[5]
        dut.str_6.value = byte_array[6]
        dut.str_7.value = byte_array[7]
        dut.length.value = actual_length
        
        await Timer(50, units='ns')
        
        if not is_value_defined(dut.is_palindrome.value):
            raise TestFailure(f"Edge {i} ({text!r}): Output undefined")
        
        result = int(dut.is_palindrome.value)
        expected_int = 1 if expected else 0
        
        if result != expected_int:
            raise TestFailure(
                f"Edge {i} ({text!r}): Expected {expected_int}, got {result}"
            )
        
        passed += 1
        dut._log.info(f"Edge {i} ({text!r}): PASSED")
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_random_strings(dut):
    """Test with randomly generated strings."""
    
    random.seed(42)
    passed = 0
    total = 15
    
    dut._log.info(f"Starting {total} random string tests...")
    
    for i in range(total):
        length = random.randint(0, 8)
        
        if length > 0:
            chars = [chr(random.randint(33, 122)) for _ in range(length)]
            text = ''.join(chars)
        else:
            text = ""
        
        expected = python_reference(text)
        byte_array = string_to_bytes(text)
        
        dut.str_0.value = byte_array[0]
        dut.str_1.value = byte_array[1]
        dut.str_2.value = byte_array[2]
        dut.str_3.value = byte_array[3]
        dut.str_4.value = byte_array[4]
        dut.str_5.value = byte_array[5]
        dut.str_6.value = byte_array[6]
        dut.str_7.value = byte_array[7]
        dut.length.value = length
        
        await Timer(50, units='ns')
        
        if not is_value_defined(dut.is_palindrome.value):
            raise TestFailure(f"Random {i} ({text!r}): Output undefined")
        
        result = int(dut.is_palindrome.value)
        expected_int = 1 if expected else 0
        
        if result != expected_int:
            raise TestFailure(
                f"Random {i} ({text!r}): Expected {expected_int}, got {result}"
            )
        
        passed += 1
        dut._log.info(f"Random {i} ({text!r}, len={length}): PASSED")
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")