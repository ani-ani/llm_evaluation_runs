import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_replacer(dut):
    test_cases = [
        ('a b c,d e f', 11, 'a:b:c:d:e:f'),
        ('ram reshma,', 11, 'ram:reshma:'),
        ('Test. String', 12, 'Test::String'),
        ('....', 4, '::::'),
        ('NoChange', 8, 'NoChange')
    ]
    
    passed = 0
    
    for original, length, expected in test_cases:
        # Pad input to 16 characters
        padded_in = original.ljust(16, '\0')
        padded_exp = expected.ljust(16, '\0')
        
        # Convert strings to ASCII arrays
        ascii_in = [ord(c) for c in padded_in]
        ascii_exp = [ord(c) if i < len(expected) else 0 for i, c in enumerate(padded_exp)]
        
        # Apply stimulus
        dut.str_len.value = length
        for i in range(16):
            dut.in_str[i].value = ascii_in[i]
        
        await Timer(1, units='ns')  # Combinational delay
        
        # Verify outputs
        errors = []
        for i in range(16):
            actual = dut.out_str[i].value.integer
            exp_val = ascii_exp[i]
            if actual != exp_val:
                errors.append(f"Position {i}: Got {actual} ({chr(actual)}), expected {exp_val} ({chr(exp_val)})")
        
        if not errors:
            passed += 1
            dut._log.info(f"PASS: '{original[:length]}' -> '{expected}'")
        else:
            dut._log.error(f"FAIL: '{original}'
{'
'.join(errors)}")
    
    dut._log.info(f"Result: {passed}/{len(test_cases)} tests passed")