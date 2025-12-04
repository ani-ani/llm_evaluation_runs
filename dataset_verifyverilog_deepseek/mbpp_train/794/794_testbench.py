import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_matcher(dut):
    test_cases = [
        ("aabbbb\0\0", 1),  # Valid case (len=6)
        ("aabAbbbc", 0),   # Invalid ending (capital B)
        ("a\0\0\0\0\0\0b", 1), # Minimal valid case (len=2)
        ("abbbbbbb", 1),   # Max length (8 chars)
        ("axxxxxxb", 1),   # Middle wildcards
        ("baaaaaab", 0)    # Wrong starting char
    ]

    passed = 0
    for text, expected in test_cases:
        # Convert string to 64-bit value
        bytes_val = 0
        for i, char in enumerate(text.ljust(8, '\\0')):
            bytes_val |= ord(char) << (56 - 8*i)
        dut.str_bytes.value = bytes_val
        await Timer(1, units='ns')
        result = dut.match_flag.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: '{text}' -> {result}")
        else:
            dut._log.error(f"FAIL: '{text}' -> {result}, expected {expected}")
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} passed")