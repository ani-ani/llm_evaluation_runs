import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_substring_count(dut):
    test_cases = [
        (0, 0),   # Empty string
        (1, 1),   # "a"
        (3, 6),   # "abc"
        (4, 10),  # "abcd"
        (5, 15),  # "abcde"
        (16, 136) # Max supported length
    ]
    passed = 0

    for length, expected in test_cases:
        dut.str_len.value = length
        await Timer(1, units='ns')
        result = dut.count.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: length={length} -> {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: length={length} -> {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")