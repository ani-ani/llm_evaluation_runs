import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_prime_length(dut):
    test_cases = [
        # Original string   Length  Expected
        (5, 1),   # 'Hello'
        (7, 1),   # 'abcdcba'
        (7, 1),   # 'kittens'
        (6, 0),   # 'orange'
        (3, 1),   # 'wow'
        (5, 1),   # 'world'
        (5, 1),   # 'MadaM'
        (3, 1),   # 'Wow'
        (0, 0),   # ''
        (2, 1),   # 'HI'
        (2, 1),   # 'go'
        (4, 0),   # 'gogo'
        (15, 0),  # 'aaaaaaaaaaaaaaa'
        (5, 1),   # 'Madam'
        (1, 0),   # 'M'
        (1, 0)    # '0'
    ]

    passed = 0
    for length, expected in test_cases:
        dut.str_len.value = length
        await Timer(1, units='ns')
        result = dut.is_prime.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: Length={length} -> {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: Length={length} -> {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")