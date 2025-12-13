import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import random
import string

@cocotb.test()
async def test_cyclic_codec(dut):
    # Helper functions
    def str_to_bits(s):
        padded = s.ljust(9, '\\0')
        return int(''.join(f"{ord(c):08b}" for c in padded), 2)
    
    def bits_to_str(bits):
        s = ''
        for i in range(8, 72, 8):
            char = chr((bits >> (72-i)) & 0xff)
            if char != '\\0':
                s += char
        return s
    
    # Test cases [input_str, mode, expected]
    test_cases = [
        ("abc", 0, "bca"),
        ("bca", 1, "abc"),
        ("abcd", 0, "bca" + "d"),  # One full group + one char
        ("defg", 1, "fde" + "g"),  # decode partial group
        ("xyz123456", 0, "yzx456123"),
        ("yzx456123", 1, "xyz123456"),
        ("", 0, ""),
        ("a", 1, "a")
    ]
    
    passed = 0
    for s_in, mode, expected in test_cases:
        # Convert to bit vectors
        input_bits = str_to_bits(s_in)
        expected_bits = str_to_bits(expected)
        
        # Apply test values
        dut.str_in.value = input_bits
        dut.mode.value = mode
        
        # Wait for combinational logic (1ns)
        await Timer(1, units='ns')
        
        # Check output
        actual = bits_to_str(int(dut.str_out.value))
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: Mode={mode} '{s_in}' -> '{actual}'")
        else:
            dut._log.error(f"FAIL: Mode {mode} Input '{s_in}' Expected '{expected}' Got '{actual}'")
    
    # Add random tests for 9-character strings
    for _ in range(3):
        letters = string.ascii_lowercase
        orig = ''.join(random.choices(letters, k=9))
        
        # Encode test
        dut.str_in.value = str_to_bits(orig)
        dut.mode.value = 0
        await Timer(1, units='ns')
        encoded = bits_to_str(int(dut.str_out.value))
        
        # Decode test
        dut.str_in.value = str_to_bits(encoded)
        dut.mode.value = 1
        await Timer(1, units='ns')
        decoded = bits_to_str(int(dut.str_out.value))
        
        if decoded == orig:
            passed += 1
            dut._log.info(f"PASS: Roundtrip '{orig}' -> '{decoded}'")
        else:
            dut._log.error(f"FAIL Roundtrip: '{orig}' -> decoded as '{decoded}'")
    
    total = len(test_cases) + 3
    dut._log.info(f"{passed}/{total} tests passed")