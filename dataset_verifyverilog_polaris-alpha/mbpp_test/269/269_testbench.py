import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_char_to_ascii(dut):
    test_cases = [
        ('A', 65),
        ('R', 82),
        ('S', 83),
        ('\\x00', 0),  # Null character edge case
        ('\\xFF', 255)  # Extended ASCII edge case
    ]
    passed = 0
    
    for char, expected in test_cases:
        dut.char.value = ord(char)  # Python ord() for numeric conversion
        await Timer(1, units='ns')
        actual = dut.ascii_val.value
        
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: '{char}' → {actual} (expected {expected})")
        else:
            dut._log.error(f"FAIL: '{char}' → {actual}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")