import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_vowel_check(dut):
    test_cases = [
        (b"annie\\x00\\x00\\x00", 1),  # Lowercase vowel
        (b"dawood\\x00\\x00", 0),   # Consonant start
        (b"Else\\x00\\x00\\x00\\x00", 1),   # Uppercase vowel
        (b"xyz\\x00\\x00\\x00\\x00\\x00", 0),   # All consonant
        (b"\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00", 0)  # Empty string
    ]

    passed = 0
    for packed_str, expected in test_cases:
        # Convert bytes to integer for packing
        str_val = int.from_bytes(packed_str, byteorder='big')
        dut.str_packed.value = str_val
        await Timer(1, units='ns')
        
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: {packed_str} -> {expected}")
        else:
            dut._log.error(f"FAIL: {packed_str} -> {dut.result.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")