import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_lower(dut):
    # Helper function to pad strings to 8 characters
    def pad_str(s):
        return s.ljust(8)[:8]
    
    test_cases = [
        ("InValid", "invalid"),
        ("TruE", "true"),
        ("SenTenCE", "sentence")
    ]
    
    passed = 0
    for input_str, expected in test_cases:
        # Prepare padded strings
        input_padded = bytes(pad_str(input_str), 'ascii')
        expected_padded = bytes(pad_str(expected), 'ascii')
        
        # Convert to 64-bit integers
        input_val = int.from_bytes(input_padded, 'big')
        expected_val = int.from_bytes(expected_padded, 'big')
        
        # Apply to DUT
        dut.string_in.value = input_val
        await Timer(1, units='ns')
        
        # Check output
        if dut.string_out.value == expected_val:
            passed += 1
            dut._log.info(f"PASS: {input_str} -> {expected}")
        else:
            # Decode output for better error messages
            output_bytes = dut.string_out.value.buff.tobytes()
            output_str = ''.join(chr(b) for b in output_bytes)
            dut._log.error(f"FAIL: '{input_str}' got '{output_str.strip()}', expected '{expected}'")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed} tests"