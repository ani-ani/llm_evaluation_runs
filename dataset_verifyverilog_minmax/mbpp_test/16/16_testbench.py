import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_text_lowercase_underscore(dut):
    test_cases = [
        # (input string, expected)
        ("aaaabbbb_ccccccc", True),   # Valid 16-byte pattern
        ("aab_Abbbc", False),         # Uppercase 'A' invalid
        ("_abcdefghijklmno", False),  # Underscore first
        ("abcdefghijklmnop", False),  # No underscore
        ("a_b_cdefghijklmn", False),  # Multiple underscores
    ]

    passed = 0
    for text, expected in test_cases:
        # Convert to 16-byte array with null padding
        byte_str = text.encode('ascii').ljust(16, b'\\x00')[:16]
        int_val = int.from_bytes(byte_str, byteorder='big')
        
        dut.text.value = int_val
        await Timer(1, units='ns')
        
        if dut.valid.value == expected:
            passed += 1
            dut._log.info(f"PASS: '{text}' => {expected}")
        else:
            dut._log.error(f"FAIL: '{text}' => {dut.valid.value}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed} test cases"