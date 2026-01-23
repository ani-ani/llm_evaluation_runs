import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def str_to_byte_array(s):
    """Convert string to list of 8-bit values, pad to 16 chars"""
    result = [ord(c) for c in s]
    while len(result) < 16:
        result.append(0)
    return result

def filter_even_indices(s):
    """Python implementation for expected output"""
    result = ""
    for i, c in enumerate(s):
        if i % 2 == 0:
            result += c
    return result

@cocotb.test()
async def test_odd_index_filter(dut):
    """Test odd index character removal with various strings"""
    
    # Test case 1: "abcdef" -> "ace"
    test_input = "abcdef"
    expected = "ace"
    input_array = str_to_byte_array(test_input)
    input_length = len(test_input)
    
    # Assign inputs
    for i in range(16):
        dut.char_array[i] = input_array[i]
    dut.length.value = input_length
    
    await Timer(10, units='ns')
    
    # Check result
    result_length = int(dut.result_length.value)
    assert result_length == len(expected), f"Test 1 failed: expected length {len(expected)}, got {result_length}"
    
    result_str = ""
    for i in range(result_length):
        char_val = int(dut.result[i].value)
        result_str += chr(char_val)
    
    assert result_str == expected, f"Test 1 failed: expected '{expected}', got '{result_str}'"
    print(f"Test 1: '{test_input}' -> '{result_str}' ✓")
    
    # Test case 2: "python" -> "pto"
    test_input = "python"
    expected = "pto"
    input_array = str_to_byte_array(test_input)
    input_length = len(test_input)
    
    for i in range(16):
        dut.char_array[i] = input_array[i]
    dut.length.value = input_length
    
    await Timer(10, units='ns')
    
    result_length = int(dut.result_length.value)
    assert result_length == len(expected), f"Test 2 failed: expected length {len(expected)}, got {result_length}"
    
    result_str = ""
    for i in range(result_length):
        char_val = int(dut.result[i].value)
        result_str += chr(char_val)
    
    assert result_str == expected, f"Test 2 failed: expected '{expected}', got '{result_str}'"
    print(f"Test 2: '{test_input}' -> '{result_str}' ✓")
    
    # Test case 3: "data" -> "dt"
    test_input = "data"
    expected = "dt"
    input_array = str_to_byte_array(test_input)
    input_length = len(test_input)
    
    for i in range(16):
        dut.char_array[i] = input_array[i]
    dut.length.value = input_length
    
    await Timer(10, units='ns')
    
    result_length = int(dut.result_length.value)
    assert result_length == len(expected), f"Test 3 failed: expected length {len(expected)}, got {result_length}"
    
    result_str = ""
    for i in range(result_length):
        char_val = int(dut.result[i].value)
        result_str += chr(char_val)
    
    assert result_str == expected, f"Test 3 failed: expected '{expected}', got '{result_str}'"
    print(f"Test 3: '{test_input}' -> '{result_str}' ✓")
    
    # Test case 4: "lambs" -> "lms"
    test_input = "lambs"
    expected = "lms"
    input_array = str_to_byte_array(test_input)
    input_length = len(test_input)
    
    for i in range(16):
        dut.char_array[i] = input_array[i]
    dut.length.value = input_length
    
    await Timer(10, units='ns')
    
    result_length = int(dut.result_length.value)
    assert result_length == len(expected), f"Test 4 failed: expected length {len(expected)}, got {result_length}"
    
    result_str = ""
    for i in range(result_length):
        char_val = int(dut.result[i].value)
        result_str += chr(char_val)
    
    assert result_str == expected, f"Test 4 failed: expected '{expected}', got '{result_str}'"
    print(f"Test 4: '{test_input}' -> '{result_str}' ✓")
    
    # Test case 5: Single character
    test_input = "a"
    expected = "a"
    input_array = str_to_byte_array(test_input)
    input_length = len(test_input)
    
    for i in range(16):
        dut.char_array[i] = input_array[i]
    dut.length.value = input_length
    
    await Timer(10, units='ns')
    
    result_length = int(dut.result_length.value)
    assert result_length == len(expected), f"Test 5 failed: expected length {len(expected)}, got {result_length}"
    
    result_str = ""
    for i in range(result_length):
        char_val = int(dut.result[i].value)
        result_str += chr(char_val)
    
    assert result_str == expected, f"Test 5 failed: expected '{expected}', got '{result_str}'"
    print(f"Test 5: '{test_input}' -> '{result_str}' ✓")
    
    # Test case 6: Empty string
    test_input = ""
    expected = ""
    input_array = str_to_byte_array(test_input)
    input_length = len(test_input)
    
    for i in range(16):
        dut.char_array[i] = input_array[i]
    dut.length.value = input_length
    
    await Timer(10, units='ns')
    
    result_length = int(dut.result_length.value)
    assert result_length == len(expected), f"Test 6 failed: expected length {len(expected)}, got {result_length}"
    print(f"Test 6: '{test_input}' -> (empty) ✓")
    
    print("
All 6 tests passed!")
