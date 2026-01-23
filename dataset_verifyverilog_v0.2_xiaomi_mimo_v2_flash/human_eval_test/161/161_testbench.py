import cocotb
from cocotb.triggers import Timer
import random

def char_to_ascii(c):
    return ord(c)

def ascii_to_char(b):
    return chr(b)

def is_letter(b):
    return (0x41 <= b <= 0x5A) or (0x61 <= b <= 0x7A)

def transform_string(input_str):
    """Python reference implementation"""
    # Ensure exactly 8 characters
    s = input_str.ljust(8, ' ')[:8]
    
    # Check if any letter exists
    has_letter = any(is_letter(ord(c)) for c in s)
    
    if has_letter:
        # Reverse case of letters, keep others
        result = []
        for c in s:
            ascii_val = ord(c)
            if 0x41 <= ascii_val <= 0x5A:  # Uppercase
                result.append(chr(ascii_val + 0x20))
            elif 0x61 <= ascii_val <= 0x7A:  # Lowercase
                result.append(chr(ascii_val - 0x20))
            else:
                result.append(c)
        return ''.join(result)
    else:
        # Reverse the string
        return s[::-1]

@cocotb.test()
async def test_string_transform(dut):
    """Test string transformation module"""
    
    # Test cases: (input_string, expected_output)
    test_cases = [
        ("AsDf", "aSdF"),
        ("1234", "4321"),
        ("ab", "AB"),
        ("#a@C", "#A@c"),
        ("#AsdfW^45", "#aSDFw^45"),
        ("#6@2", "2@6#"),
        ("#$a^D", "#$A^d"),
        ("#ccc", "#CCC"),
        ("ABCDEFGH", "abcdefgh"),
        ("abcdefgh", "ABCDEFGH"),
        ("12345678", "87654321"),
        ("A1b2C3d4", "a1B2c3D4"),
        ("!!!!", "!!!!"),
        ("aBcDeFgH", "AbCdEfGh"),
        ("1a2b3c4d", "1A2B3C4D"),
        ("Z" + " " * 7, "z" + " " * 7),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for input_str, expected in test_cases:
        # Pad/truncate to 8 characters
        s = input_str.ljust(8, ' ')[:8]
        
        # Set inputs
        for i in range(8):
            ascii_val = ord(s[i]) if i < len(s) else 32
            setattr(dut, f'char_{i}', ascii_val)
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read outputs
        outputs = [getattr(dut, f'out_{i}').value.integer for i in range(8)]
        result = ''.join(ascii_to_char(b) for b in outputs)
        
        # Verify
        assert result == expected, f"Failed: '{input_str}' -> got '{result}', expected '{expected}'"
        print(f"✓ Test '{input_str}' -> '{result}'")
        passed += 1
    
    print(f"
{passed}/{total} tests passed")

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases"""
    
    edge_cases = [
        # All spaces (no letters) -> reverse
        ("        ", "        "),
        # Mixed with numbers
        ("a1B2c3D4", "A1b2C3d4"),
        # All uppercase letters
        ("ABCD1234", "abcd1234"),
        # All lowercase letters
        ("xyz12345", "XYZ12345"),
        # Special chars only
        ("!@#$%^&*", "*&^%$#@!"),
    ]
    
    passed = 0
    total = len(edge_cases)
    
    for input_str, expected in edge_cases:
        s = input_str.ljust(8, ' ')[:8]
        
        # Set inputs
        for i in range(8):
            ascii_val = ord(s[i])
            setattr(dut, f'char_{i}', ascii_val)
        
        await Timer(10, units='ns')
        
        outputs = [getattr(dut, f'out_{i}').value.integer for i in range(8)]
        result = ''.join(ascii_to_char(b) for b in outputs)
        
        assert result == expected, f"Edge case failed: got '{result}', expected '{expected}'"
        print(f"✓ Edge case '{input_str}' -> '{result}'")
        passed += 1
    
    print(f"
{passed}/{total} edge case tests passed")