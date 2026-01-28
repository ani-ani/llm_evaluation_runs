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

def int_to_roman_expected(number):
    """Expected roman numeral conversion function."""
    if number == 0:
        return "", 0
    
    # Lookup tables
    thousands = ["", "m"]
    hundreds = ["", "c", "cc", "ccc", "cd", "d", "dc", "dcc", "dccc", "cm"]
    tens = ["", "x", "xx", "xxx", "xl", "l", "lx", "lxx", "lxxx", "xc"]
    ones = ["", "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix"]
    
    th = number // 1000
    h = (number % 1000) // 100
    t = (number % 100) // 10
    o = number % 10
    
    result = thousands[th] + hundreds[h] + tens[t] + ones[o]
    return result, len(result)

def pack_string(s):
    """Pack string into 128-bit integer (little-endian: char 0 at bits 7:0)."""
    packed = 0
    for i, char in enumerate(s):
        packed |= (ord(char) << (i * 8))
    return packed

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_roman_converter(dut):
    """Test the roman converter module."""
    
    # Test cases: (input, expected_string)
    test_cases = [
        (1, "i"),
        (4, "iv"),
        (9, "ix"),
        (19, "xix"),
        (40, "xl"),
        (43, "xliii"),
        (50, "l"),
        (90, "xc"),
        (94, "xciv"),
        (100, "c"),
        (152, "clii"),
        (251, "ccli"),
        (400, "cd"),
        (426, "cdxxvi"),
        (500, "d"),
        (532, "dxxxii"),
        (900, "cm"),
        (994, "cmxciv"),
        (1000, "m"),
        (0, ""),  # Edge case: zero
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (num_in, expected_str) in enumerate(test_cases):
        # Set input
        dut.number.value = num_in
        
        # Wait for combinational logic to settle
        await Timer(100, units='ns')
        
        # Check outputs are defined
        if not is_value_defined(dut.roman_string.value):
            raise TestFailure(f"Test {i}: roman_string is undefined (X/Z)")
        if not is_value_defined(dut.length.value):
            raise TestFailure(f"Test {i}: length is undefined (X/Z)")
        
        # Read outputs
        packed_output = int(dut.roman_string.value)
        length_output = int(dut.length.value)
        
        # Verify length
        if length_output != len(expected_str):
            raise TestFailure(f"Test {i} (n={num_in}): expected length {len(expected_str)}, got {length_output}")
        
        # Verify string content
        if length_output > 0:
            # Extract characters from packed output
            extracted_chars = []
            for pos in range(length_output):
                char_val = (packed_output >> (pos * 8)) & 0xFF
                extracted_chars.append(chr(char_val))
            extracted_str = ''.join(extracted_chars)
            
            if extracted_str != expected_str:
                raise TestFailure(f"Test {i} (n={num_in}): expected '{expected_str}', got '{extracted_str}'")
        
        dut._log.info(f"Test {i} (n={num_in}): PASS - '{expected_str}'")
        passed += 1
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Not all tests passed ({passed}/{total})")

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_roman_converter_random(dut):
    """Test with random inputs to verify correctness."""
    random.seed(42)
    test_count = 20
    
    passed = 0
    for i in range(test_count):
        num = random.randint(0, 1000)
        expected_str, expected_len = int_to_roman_expected(num)
        
        dut.number.value = num
        await Timer(100, units='ns')
        
        if not is_value_defined(dut.roman_string.value) or not is_value_defined(dut.length.value):
            continue
        
        length_output = int(dut.length.value)
        packed_output = int(dut.roman_string.value)
        
        # Extract string
        extracted_chars = []
        for pos in range(length_output):
            char_val = (packed_output >> (pos * 8)) & 0xFF
            extracted_chars.append(chr(char_val))
        extracted_str = ''.join(extracted_chars)
        
        if extracted_str == expected_str and length_output == expected_len:
            passed += 1
        else:
            dut._log.error(f"Random test {i} (n={num}): expected '{expected_str}' (len={expected_len}), got '{extracted_str}' (len={length_output})")
    
    dut._log.info(f"Random tests: {passed}/{test_count} passed")
    
    if passed != test_count:
        raise TestFailure(f"Random tests failed: {passed}/{test_count}")