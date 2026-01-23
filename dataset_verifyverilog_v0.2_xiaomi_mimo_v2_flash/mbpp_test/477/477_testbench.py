import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

# Helper function to convert string to ASCII values
def string_to_ascii(s, length=8):
    ascii_vals = [ord(c) for c in s[:length]]
    # Pad with spaces (0x20) if needed
    while len(ascii_vals) < length:
        ascii_vals.append(0x20)
    return ascii_vals

# Helper function to convert ASCII values back to string
def ascii_to_string(ascii_vals):
    return ''.join(chr(val) for val in ascii_vals if val != 0x20).rstrip()

@cocotb.test()
async def test_string_to_lower(dut):
    """Test string to lowercase conversion"""
    
    # Test cases: (input_string, expected_output_string)
    test_cases = [
        ("InValid", "invalid"),
        ("TruE", "true"),
        ("SenTenCE", "sentence"),
        ("ABC", "abc"),  # Edge case: all uppercase
        ("xyz", "xyz"),  # Edge case: already lowercase
        ("123AbC", "123abc"),  # Mixed case with numbers
        ("A", "a"),  # Single character
        ("", ""),  # Empty string
    ]
    
    passed = 0
    total = len(test_cases)
    
    print(f"
Running {total} tests...")
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        print(f"
Test {i+1}: '{input_str}' -> '{expected_str}'")
        
        # Convert input string to ASCII values
        ascii_vals = string_to_ascii(input_str, length=8)
        
        # Set inputs
        dut.char_0.value = ascii_vals[0]
        dut.char_1.value = ascii_vals[1]
        dut.char_2.value = ascii_vals[2]
        dut.char_3.value = ascii_vals[3]
        dut.char_4.value = ascii_vals[4]
        dut.char_5.value = ascii_vals[5]
        dut.char_6.value = ascii_vals[6]
        dut.char_7.value = ascii_vals[7]
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read outputs
        output_ascii = [
            int(dut.lower_char_0.value),
            int(dut.lower_char_1.value),
            int(dut.lower_char_2.value),
            int(dut.lower_char_3.value),
            int(dut.lower_char_4.value),
            int(dut.lower_char_5.value),
            int(dut.lower_char_6.value),
            int(dut.lower_char_7.value),
        ]
        
        # Convert to string
        output_str = ascii_to_string(output_ascii)
        
        print(f"  Output: '{output_str}'")
        print(f"  Expected: '{expected_str}'")
        print(f"  Output ASCII: {[hex(x) for x in output_ascii]}")
        
        # Check result
        if output_str == expected_str:
            print(f"  ✓ PASS")
            passed += 1
        else:
            print(f"  ✗ FAIL")
            raise TestFailure(f"Test {i+1} failed: expected '{expected_str}', got '{output_str}'")
    
    print(f"
{'='*50}")
    print(f"Test Summary: {passed}/{total} tests passed")
    print(f"{'='*50}")
