import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_same_chars(dut):
    test_cases = [
        # (s0_chars, s1_chars, expected)
        # Original tests adapted: max 8 chars, lowercase only
        ([b'a',b'b',b'c',0,0,0,0,0], [b'c',b'b',b'a',0,0,0,0,0], True),  # abcd/dddabc adaptation
        ([b'd',b'd',b'a',b'b',b'c',0,0,0], [b'a',b'b',b'c',b'd',0,0,0,0], True),
        ([b'e',b'a',b'b',b'c',b'd',0,0,0], [b'd',b'a',b'b',b'c',0,0,0,0], False),  # eabcd vs ddddabc
        ([b'a',b'b',b'c',b'd',0,0,0,0], [b'd',b'c',b'b',b'a',0,0,0,0], True),
        ([b'a',b'a',b'b',b'b',0,0,0,0], [b'a',b'c',0,0,0,0,0,0], False)  # aabb vs aaccc
    ]

    passed = 0
    for s0_arr, s1_arr, expected in test_cases:
        # Pack characters into 40-bit inputs
        s0_val = 0
        s1_val = 0
        for i, char in enumerate(s0_arr):
            char_code = char if char != 0 else 0
            s0_val |= (char_code - 97 if char_code != 0 else 0) << (i*5)
        for i, char in enumerate(s1_arr):
            char_code = char if char != 0 else 0
            s1_val |= (char_code - 97 if char_code != 0 else 0) << (i*5)

        dut.s0.value = s0_val
        dut.s1.value = s1_val
        await Timer(1, units='ns')

        result = dut.result.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {'T' if expected else 'F'}")
        else:
            dut._log.error(f"FAIL: Expected {expected} got {result}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
