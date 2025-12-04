import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_string_xor(dut):
    # Adapted test cases with 8-bit padding
    test_cases = [
        ('111000', '101010', '010010'),
        ('1', '1', '0'),
        ('0101', '0000', '0101')
    ]
    
    passed = 0
    for a_str, b_str, expected_str in test_cases:
        # Pad all inputs and expected output to 8 bits
        a_padded = a_str.zfill(8)
        b_padded = b_str.zfill(8)
        expected_padded = expected_str.zfill(8)
        
        # Convert to integers
        a_val = int(a_padded, 2)
        b_val = int(b_padded, 2)
        expected_val = int(expected_padded, 2)
        
        dut.a.value = a_val
        dut.b.value = b_val
        await Timer(1, units='ns')  # Combinational delay
        
        actual_val = dut.result.value
        if actual_val == expected_val:
            passed += 1
            dut._log.info(f"PASS: {a_str.zfill(8)}
    ^ {b_str.zfill(8)}
    = {expected_padded}")
        else:
            actual_bits = bin(actual_val)[2:].zfill(8)
            dut._log.error(f"FAIL: {a_str} XOR {b_str}
    Expected {expected_padded} ({expected_val})
    Got      {actual_bits} ({actual_val})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")