import cocotb
from cocotb.triggers import Timer
@cocotb.test()
async def test_char_counter(dut):
    # Original tests padded to 8 chars with spaces (ASCII 32)
    test_cases = [
        ("xbcefg  ", 2),  # Original: "xbcefg"
        ("ABcED   ", 3),  # Original: "ABcED"
        ("AbgdeF  ", 5),  # Original: "AbgdeF"
        ("abcdefgh", 8),  # All match (a=pos0, b=pos1,...h=pos7)
        ("XYZABCDE", 0)   # None match (positions 0-7 vs X,Y,Z,A,B,C,D,E)
    ]
    passed = 0
    for s, expected in test_cases:
        # Convert string to ASCII values
        ascii_values = [ord(c) for c in s]
        # Apply to DUT inputs
        for i in range(8):
            dut.str[i].value = ascii_values[i]
        await Timer(1, units='ns')
        result = dut.count.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: '{s}' -> {int(result)} (expected {expected})")
        else:
            dut._log.error(f"FAIL: '{s}' -> {int(result)}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")