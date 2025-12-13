import cocotb
from cocotb.triggers import Timer

def string_to_vector(s):
    padded = s.ljust(16, '\\0')
    return int.from_bytes(padded.encode(), 'little')

def filter_reference(str1, str2):
    keep_chars = [c for c in str1 if c not in str2]
    return ''.join(keep_chars).ljust(16, '\\0').encode()

@cocotb.test()
async def test_string_filter(dut):
    test_cases = [
        ("probasscurve", "pros"),
        ("digitalindia", "talent"),
        ("exoticmiles", "toxic"),
        ("abcdefghijklmnop", "acegikmo"),  # Max length test
        ("", "abc")  # Empty input test
    ]
    
    passed = 0
    for str1, str2 in test_cases:
        # Get reference result
        expected = filter_reference(str1, str2)
        expected_int = int.from_bytes(expected, 'little')
        
        # Apply inputs
        dut.str1.value = string_to_vector(str1)
        dut.str2.value = string_to_vector(str2)
        
        # Wait for combinatorial logic
        await Timer(1, units='ns')
        
        # Check result
        actual = dut.filtered_str.value.integer.to_bytes(16, 'little')
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: '{str1}' - '{str2}' => '{actual.decode().strip('\\0')}'")
        else:
            # Find first mismatch
            expected_str = expected.decode().rstrip('\\0')
            actual_str = actual.decode().rstrip('\\0')
            dut._log.error(f"FAIL: '{str1}' - '{str2}' => '{actual_str}' (expected '{expected_str}')")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")