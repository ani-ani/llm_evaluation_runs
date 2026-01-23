import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_replace_blank(dut):
    """Test string space replacement functionality"""
    
    # Helper function to convert string to 128-bit value
    def str_to_128(s):
        # Pad to 16 characters with spaces
        padded = s.ljust(16, ' ')
        result = 0
        for i, char in enumerate(padded):
            result |= ord(char) << (8 * (15 - i))  # Pack as big-endian
        return result
    
    # Helper function to convert 128-bit value to string
    def _128_to_str(val):
        result = ""
        for i in range(16):
            byte_val = (val >> (8 * (15 - i))) & 0xFF
            if byte_val != ord(' '):
                result += chr(byte_val)
        return result
    
    # Test case 1: "hello people" -> "hello@people"
    dut.str_in.value = str_to_128("hello people")
    dut.char_in.value = ord('@')
    await Timer(1, units='ns')
    expected = str_to_128("hello@people")
    actual = dut.str_out.value.integer
    assert actual == expected, f"Test 1 failed: expected {_128_to_str(expected)}, got {_128_to_str(actual)}"
    print("Test 1 passed: 'hello people' -> 'hello@people'")
    
    # Test case 2: "python program language" -> "python$program$language"
    dut.str_in.value = str_to_128("python program language")
    dut.char_in.value = ord('$')
    await Timer(1, units='ns')
    expected = str_to_128("python$program$language")
    actual = dut.str_out.value.integer
    assert actual == expected, f"Test 2 failed: expected {_128_to_str(expected)}, got {_128_to_str(actual)}"
    print("Test 2 passed: 'python program language' -> 'python$program$language'")
    
    # Test case 3: "blank space" -> "blank-space"
    dut.str_in.value = str_to_128("blank space")
    dut.char_in.value = ord('-')
    await Timer(1, units='ns')
    expected = str_to_128("blank-space")
    actual = dut.str_out.value.integer
    assert actual == expected, f"Test 3 failed: expected {_128_to_str(expected)}, got {_128_to_str(actual)}"
    print("Test 3 passed: 'blank space' -> 'blank-space'")
    
    # Additional edge case: Multiple consecutive spaces
    dut.str_in.value = str_to_128("a  b")
    dut.char_in.value = ord('#')
    await Timer(1, units='ns')
    expected = str_to_128("a##b")
    actual = dut.str_out.value.integer
    assert actual == expected, f"Edge case failed: expected {_128_to_str(expected)}, got {_128_to_str(actual)}"
    print("Edge case passed: 'a  b' -> 'a##b'")
    
    # Edge case: No spaces
    dut.str_in.value = str_to_128("test")
    dut.char_in.value = ord('@')
    await Timer(1, units='ns')
    expected = str_to_128("test")
    actual = dut.str_out.value.integer
    assert actual == expected, f"No-space case failed"
    print("Edge case passed: 'test' unchanged")
    
    # Edge case: All spaces
    dut.str_in.value = str_to_128("                ")
    dut.char_in.value = ord('*')
    await Timer(1, units='ns')
    expected = str_to_128("****************")
    actual = dut.str_out.value.integer
    assert actual == expected, f"All-space case failed"
    print("Edge case passed: all spaces replaced")
    
    print(f"
=== Results: 6/6 tests passed ===")