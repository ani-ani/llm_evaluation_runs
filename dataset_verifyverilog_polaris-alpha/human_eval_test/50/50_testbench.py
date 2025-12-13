import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_shift_decode(dut):
    test_cases = [
        # Basic no-wrap
        ('abcdefgh', 'vwxyzabc'),  # "abcdefgh" encoded becomes "vwxyzabc"
        # Full wrap-around
        ('vwxyzabc', 'qrstuvwx'),  # "vwxyzabc" decoded back to "qrstuvwx"
        # Mixed wrap
        ('nopqrstu', 'ijklmnop'),
        # Edge case: 'a' (97) becomes 'v' (118)
        ('aaaaaaa', 'vvvvvv'),
    ]
    
    passed = 0
    for expected, encoded in test_cases:
        # Pad inputs to 8 characters with 'a'
        encoded_padded = encoded.ljust(8, 'a')
        expected_padded = expected.ljust(8, 'a')
        
        # Convert strings to 64-bit values
        encoded_val = int.from_bytes(encoded_padded.encode(), byteorder='big')
        expected_val = int.from_bytes(expected_padded.encode(), byteorder='big')
        
        dut.encoded_str.value = encoded_val
        await Timer(1, units='ns')
        
        if dut.decoded_str.value == expected_val:
            passed += 1
            dut._log.info(f"PASS: {encoded} -> {expected}")
        else:
            received = dut.decoded_str.value.buff[::-1].tobytes().decode().strip('\\x00')
            dut._log.error(f"FAIL: {encoded} -> {received} (expected {expected})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")