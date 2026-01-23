import cocotb
from cocotb.triggers import Timer

def ascii_to_hex(s):
    """Convert ASCII string to hex bytes"""
    return [ord(c) for c in s]

def hex_to_ascii(hex_list):
    """Convert hex bytes back to ASCII string"""
    return ''.join(chr(h) for h in hex_list)

def pad_string(s, length=16):
    """Pad string to 16 characters with nulls"""
    return s.ljust(length, '\x00')

def replace_specialchar_python(s):
    """Python reference implementation"""
    import re
    return re.sub("[ ,.]", ":", s)

@cocotb.test()
async def test_replace_specialchar(dut):
    """Test replace_specialchar module"""
    
    # Test cases
    test_cases = [
        ('Python language, Programming language.', 'Python:language::Programming:language:'),
        ('a b c,d e f', 'a:b:c:d:e:f'),
        ('ram reshma,ram rahim', 'ram:reshma:ram:rahim'),
        ('test.only', 'test:only'),  # dot only
        ('hello world', 'hello:world'),  # space only
        ('a,b.c', 'a:b:c'),  # mixed
        ('normal', 'normal'),  # no replacements
        ('   ', ':::'),  # only spaces
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        # Pad input to 16 characters
        padded_input = pad_string(input_str, 16)
        input_bytes = ascii_to_hex(padded_input)
        
        # Convert to integer (128-bit)
        input_val = 0
        for j, b in enumerate(input_bytes):
            input_val |= (b << (8 * j))
        
        # Set inputs
        dut.text_in.value = input_val
        dut.valid_len.value = len(input_str)
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read outputs
        output_val = dut.text_out.value.integer
        out_len = dut.out_len.value.integer
        
        # Extract bytes
        output_bytes = []
        for j in range(16):
            output_bytes.append((output_val >> (8 * j)) & 0xFF)
        
        # Convert to string (trim nulls)
        output_str = ''.join(chr(b) for b in output_bytes if b != 0)
        
        # Expected
        expected_padded = pad_string(expected_str, 16)
        expected_bytes = ascii_to_hex(expected_padded)
        
        # Verify
        if output_bytes == expected_bytes and out_len == len(input_str):
            passed += 1
            print(f"Test {i+1}: PASS - '{input_str}' → '{output_str}'")
        else:
            print(f"Test {i+1}: FAIL - '{input_str}'")
            print(f"  Expected: {expected_str}")
            print(f"  Got: {output_str}")
            print(f"  Expected bytes: {[hex(b) for b in expected_bytes[:len(input_str)]]}")
            print(f"  Got bytes: {[hex(b) for b in output_bytes[:len(input_str)]]}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
