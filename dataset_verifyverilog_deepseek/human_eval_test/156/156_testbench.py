import cocotb
from cocotb.triggers import Timer

def prepare_expected(s):
    # Convert string to 12-byte array with null padding
    byte_list = list(s.encode())
    return byte_list + [0]*(12-len(byte_list))

@cocotb.test()
async def test_converter(dut):
    test_cases = [
        (19, 'xix'),
        (152, 'clii'),
        (251, 'ccli'),
        (500, 'd'),
        (1, 'i'),
        (900, 'cm'),
        (1000, 'm')
    ]
    
    passed = 0
    for num, expected_str in test_cases:
        dut.number.value = num
        await Timer(1, units='ns')
        
        expected_bytes = prepare_expected(expected_str)
        received = [int(b) for b in dut.roman_chars.value]
        
        # Compare only up to string length
        match_len = min(len(expected_str), 12)
        if received[:match_len] == expected_bytes[:match_len]:
            passed += 1
            dut._log.info(f"PASS: {num} → {expected_str}")
        else:
            actual_str = bytes(b for b in received if b != 0).decode('ascii')
            dut._log.error(f"FAIL: {num} got '{actual_str}', expected '{expected_str}'")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")