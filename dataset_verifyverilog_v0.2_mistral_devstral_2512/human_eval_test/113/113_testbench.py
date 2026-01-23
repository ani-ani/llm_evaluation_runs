import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_odd_count(dut):
    """Test odd_count module with various digit strings"""
    
    # Helper function to convert string to input format
    def str_to_bytes(s):
        # Pad to 8 characters with spaces (0x20) or nulls
        bytes_out = [0] * 8
        for i, char in enumerate(s[:8]):
            bytes_out[i] = ord(char)
        return bytes_out
    
    # Helper to convert output bytes to string
    def bytes_to_str(byte_array):
        # Extract first null or space terminated string
        result = []
        for byte in byte_array:
            if byte == 0:
                break
            result.append(chr(byte))
        return ''.join(result)
    
    test_cases = [
        # (input_string, expected_count, expected_output)
        ('1234567', 4, "the number of odd elements 4n the str4ng 4 of the 4nput."),
        ('3', 1, "the number of odd elements 1n the str1ng 1 of the 1nput."),
        ('11111111', 8, "the number of odd elements 8n the str8ng 8 of the 8nput."),
        ('271', 2, "the number of odd elements 2n the str2ng 2 of the 2nput."),
        ('137', 3, "the number of odd elements 3n the str3ng 3 of the 3nput."),
        ('314', 2, "the number of odd elements 2n the str2ng 2 of the 2nput."),
        ('2468', 0, "the number of odd elements 0n the str0ng 0 of the 0nput."),
        ('99999999', 8, "the number of odd elements 8n the str8ng 8 of the 8nput."),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for input_str, expected_count, expected_output in test_cases:
        # Setup input
        input_bytes = str_to_bytes(input_str)
        for i in range(8):
            dut.input_str[i].value = input_bytes[i]
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        # Extract the 256-bit result as byte array
        output_val = dut.result.value
        output_bytes = []
        for i in range(32):  # 32 bytes in 256 bits
            byte = (output_val >> (i * 8)) & 0xFF
            output_bytes.append(byte)
        
        output_str = bytes_to_str(output_bytes)
        
        # Print for debugging
        print(f"Input: '{input_str}' -> Count: {expected_count}")
        print(f"Expected: '{expected_output}'")
        print(f"Got:      '{output_str}'")
        
        # Verify
        if output_str == expected_output:
            passed += 1
            print("✓ PASS
")
        else:
            print(f"✗ FAIL
")
            # Debug: show where they differ
            for idx, (e, g) in enumerate(zip(expected_output, output_str)):
                if e != g:
                    print(f"  Diff at pos {idx}: expected '{e}' ({ord(e)}), got '{g}' ({ord(g)})")
                    break
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed} out of {total} tests passed"
