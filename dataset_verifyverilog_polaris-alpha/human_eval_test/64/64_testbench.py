import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_vowel_counter(dut):
    # Helper to convert string
    def encode(s):
        val = 0
        s_trunc = s[:8]
        for i, c in enumerate(s_trunc):
            val |= ord(c) << (i*8)
        return val

    test_cases = [
        ("abcde", 2),  # 'a','e'
        ("Alone", 3),  # 'A','o','e'
        ("key", 2),    # 'e' and end 'y'
        ("bye", 1),    # 'e' (only last char vowel)
        ("keY", 2),    # 'e' + end 'Y'
        ("bYe", 1),    # 'e' (last char)
        ("ACEDY", 3),   # 'A','E','Y'
        ("", 0),       # empty
        ("y", 1),      # only y at end
        ("a", 1),      # single vowel
        ("x", 0),      # no vowels
        ("ay", 2),     # 'a' + end 'y'
        ("ya", 1)      # 'a' (only last char counts as vowel)
    ]

    passed = 0
    for s, expected in test_cases:
        dut.chars.value = encode(s)
        dut.len.value = min(len(s), 8)
        await Timer(1, units='ns')
        actual = dut.count.value
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: '{s}' => {actual} vowels")
        else:
            dut._log.error(f"FAIL: '{s}' => {actual}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, "Some tests failed"