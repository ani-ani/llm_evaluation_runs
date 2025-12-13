import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_vowel_counter(dut):
    def str_to_bits(s):
        # Pad to 16 chars with null bytes
        padded = s.ljust(16, '\\0')[:16]
        # Convert to 128-bit value (little-endian: first char at LSB)
        val = 0
        for i, c in enumerate(padded):
            val |= ord(c) << (8*i)
        return val
    
    test_cases = [
        ("bestinstareels", 14, 7),   # Original test 1 (14 chars)
        ("partofthejourn", 14, 9),   # Reduced from original test 2
        ("amazonprime", 11, 5),      # Original test 3 (11 chars)
        ("edge", 4, 2),              # Custom edge case: 'd' and 'g' qualified
        ("a", 1, 0)                  # Single char test
    ]
    
    passed = 0
    for s, length, expected in test_cases:
        dut.str_flat.value = str_to_bits(s)
        dut.str_len.value = length
        await Timer(1, units='ns')
        result = dut.count.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: '{s}' ({length}) → {result}")
        else:
            dut._log.error(f"FAIL: '{s}' ({length}) got {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")