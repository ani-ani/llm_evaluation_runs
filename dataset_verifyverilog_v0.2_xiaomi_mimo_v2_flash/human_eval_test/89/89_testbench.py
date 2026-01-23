import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_string_encrypt(dut):
    """Test string encryption module"""
    
    # Helper function to convert string to individual character inputs
    def set_inputs(input_str):
        chars = [ord(c) for c in input_str]
        dut.length.value = len(chars)
        # Pad to 8 characters
        while len(chars) < 8:
            chars.append(0x00)
        dut.char_0.value = chars[0]
        dut.char_1.value = chars[1]
        dut.char_2.value = chars[2]
        dut.char_3.value = chars[3]
        dut.char_4.value = chars[4]
        dut.char_5.value = chars[5]
        dut.char_6.value = chars[6]
        dut.char_7.value = chars[7]
    
    # Helper function to get output string
    def get_output():
        output_chars = []
        output_chars.append(int(dut.enc_0.value))
        output_chars.append(int(dut.enc_1.value))
        output_chars.append(int(dut.enc_2.value))
        output_chars.append(int(dut.enc_3.value))
        output_chars.append(int(dut.enc_4.value))
        output_chars.append(int(dut.enc_5.value))
        output_chars.append(int(dut.enc_6.value))
        output_chars.append(int(dut.enc_7.value))
        length = int(dut.length.value)
        return ''.join([chr(c) for c in output_chars[:length]])
    
    # Test case 1: 'hi' -> 'lm'
    set_inputs('hi')
    await Timer(10, units='ns')
    result = get_output()
    print(f"Test 1: 'hi' -> '{result}' (expected 'lm')")
    assert result == 'lm', f"Expected 'lm', got '{result}'"
    
    # Test case 2: 'asdfghjkl' -> 'ewhjklnop' (truncated to 8 chars: 'asdfghjk' -> 'ewhjklno')
    set_inputs('asdfghjk')
    await Timer(10, units='ns')
    result = get_output()
    print(f"Test 2: 'asdfghjk' -> '{result}' (expected 'ewhjklno')")
    assert result == 'ewhjklno', f"Expected 'ewhjklno', got '{result}'"
    
    # Test case 3: 'gf' -> 'kj'
    set_inputs('gf')
    await Timer(10, units='ns')
    result = get_output()
    print(f"Test 3: 'gf' -> '{result}' (expected 'kj')")
    assert result == 'kj', f"Expected 'kj', got '{result}'"
    
    # Test case 4: 'et' -> 'ix'
    set_inputs('et')
    await Timer(10, units='ns')
    result = get_output()
    print(f"Test 4: 'et' -> '{result}' (expected 'ix')")
    assert result == 'ix', f"Expected 'ix', got '{result}'"
    
    # Test case 5: 'a' -> 'e'
    set_inputs('a')
    await Timer(10, units='ns')
    result = get_output()
    print(f"Test 5: 'a' -> '{result}' (expected 'e')")
    assert result == 'e', f"Expected 'e', got '{result}'"
    
    # Test case 6: Wrap around test - 'wxyz' -> '{bc'}
    set_inputs('wxyz')
    await Timer(10, units='ns')
    result = get_output()
    print(f"Test 6: 'wxyz' -> '{result}' (expected '{{bc')")
    assert result == '{bc', f"Expected '{{bc', got '{result}'"
    
    # Test case 7: Mixed case and non-alphabet (should remain unchanged)
    set_inputs('ab12')
    await Timer(10, units='ns')
    result = get_output()
    print(f"Test 7: 'ab12' -> '{result}' (expected 'ef12')")
    assert result == 'ef12', f"Expected 'ef12', got '{result}'"
    
    # Test case 8: Single character wrap - 'z' -> 'd'
    set_inputs('z')
    await Timer(10, units='ns')
    result = get_output()
    print(f"Test 8: 'z' -> '{result}' (expected 'd')")
    assert result == 'd', f"Expected 'd', got '{result}'"
    
    # Summary
    print("
All tests passed!")
