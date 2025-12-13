import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_remover(dut):
    test_cases = [
        # (input_str, input_char, expected_str)
        ("hello\\0\\0\\0", 'l', "heo\\0\\0\\0\\0"),  # Original "hello" → "heo"
        ("abcda\\0\\0\\0", 'a', "bcd\\0\\0\\0\\0"),  # Original "abcda" → "bcd"
        ("PHP\\0\\0\\0\\0", 'P', "H\\0\\0\\0\\0\\0"),  # Original "PHP" → "H"
        ("miss\\0\\0\\0\\0", 's', "mi\\0\\0\\0\\0\\0"),  # Remove first and last 's'
        ("a\\0\\0\\0\\0\\0\\0", 'a', "\\0\\0\\0\\0\\0\\0\\0"),  # Single occurrence removal
        ("test\\0\\0\\0\\0", 'x', "test\\0\\0\\0\\0")  # No removal needed
    ]
    
    passed = 0
    for s_in, char, expected in test_cases:
        # Convert strings to 64-bit representations
        inp_val = int.from_bytes(s_in.encode(), 'little')
        exp_val = int.from_bytes(expected.encode(), 'little')
        char_val = ord(char)
        
        dut.str_in.value = inp_val
        dut.ch.value = char_val
        await Timer(1, units='ns')
        
        actual = dut.str_out.value.integer
        actual_str = actual.to_bytes(8, 'little').decode().strip('\\0')
        expected_str = expected.strip('\\0')
        
        if actual == exp_val:
            passed += 1
            dut._log.info(f"PASS: '{s_in.strip('\\0')}' -> '{expected_str}'")
        else:
            dut._log.error(f"FAIL: '{s_in.strip('\\0')}' removed '{char}' -> '{actual_str}', expected '{expected_str}'")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed} tests"