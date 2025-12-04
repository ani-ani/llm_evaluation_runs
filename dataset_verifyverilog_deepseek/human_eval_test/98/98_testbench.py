import cocotb
from cocotb.triggers import Timer

def str_to_bytes(s):
    bytes = [0]*8
    for i in range(min(len(s),8)):
        bytes[7-i] = ord(s[i]) if i < len(s) else 0
    return (bytes[0] << 56) | (bytes[1] << 48) | (bytes[2] << 40) | (bytes[3] << 32) \
          | (bytes[4] << 24) | (bytes[5] << 16) | (bytes[6] << 8) | bytes[7]

@cocotb.test()
async def test_count_upper(dut):
    test_cases = [
        ('aBCdEf', 1),  # 'E' at index 4 (char[4])
        ('abcdefg', 0),
        ('dBBE', 0),
        ('B', 0),
        ('U', 1),       # 'U' at index 0
        ('', 0),
        ('EEEE', 2)     # 'E' at indices 0,2 (chars[0], [2])
    ]
    
    passed = 0
    for s, expected in test_cases:
        dut.chars.value = str_to_bytes(s)
        await Timer(1, units='ns')
        result = dut.count.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: '{s}' -> {result}")
        else:
            dut._log.error(f"FAIL: '{s}' -> {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)