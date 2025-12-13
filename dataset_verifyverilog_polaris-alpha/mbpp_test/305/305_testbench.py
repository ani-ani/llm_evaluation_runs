import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_find_p_words(dut):
    # Helper to convert strings to 128-bit values
    def str_to_bits(s):
        s = s.ljust(16, '\\0')
        return int.from_bytes(s.encode('ascii'), 'big')
    
    # Test cases (input_bits, expected_word1, expected_word2, expected_valid)
    test_cases = [
        ("Python PHP \0\0\0\0\0\0", 0x507974686F6E0000, 0x5048500000000000, 1),
        ("PythonPro \0\0\0\0\0\0", 0x507974686F6E5072, 0x6F00000000000000, 0),  # No space = invalid
        ("Pqrst Pqr \0\0\0\0\0", 0x5071727374000000, 0x5071720000000000, 1),
        ("Java JavaScript\0\0", 0x4A61766100000000, 0x4A617661536372, 0)  # Starts with J
    ]

    passed = 0
    for str_val, exp_w1, exp_w2, exp_vld in test_cases:
        dut.str_input.value = str_to_bits(str_val)
        await Timer(1, units='ns')
        
        actual_valid = dut.valid.value
        w1_match = dut.word1.value == exp_w1
        w2_match = dut.word2.value == exp_w2
        
        if actual_valid == exp_vld and w1_match and w2_match:
            passed += 1
            dut._log.info(f"PASS: {str_val.strip()} -> ({hex(exp_w1)},{hex(exp_w2)},{exp_vld})")
        else:
            err_msg = f"FAIL: {str_val.strip()} -> word1={hex(dut.word1.value)} (exp {hex(exp_w1)}), " \
                      f"word2={hex(dut.word2.value)} (exp {hex(exp_w2)}), valid={actual_valid} (exp {exp_vld})"
            dut._log.error(err_msg)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)