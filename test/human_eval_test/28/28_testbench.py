import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue

@cocotb.test()
async def test_concat(dut):
    # Test cases (valid_mask, strings array, expected)
    test_cases = [
        (0b0000, [0,0,0,0], '\0'*16),  # Empty case
        (0b0111, [
            0x78787878,  # 'xxxx'
            0x79797979,  # 'yyyy'
            0x7A7A7A7A,  # 'zzzz'
            0x00000000], 'xyz' + '\0'*13),  # Only first 3 valid
        (0b1111, [
            0x61626364,  # 'abcd'
            0x65666768,  # 'efgh'
            0x696A6B6C,  # 'ijkl'
            0x6D6E6F70], 'abcdefghijklmnop')
    ]
    passed = 0

    for valid_mask, strings, expected in test_cases:
        dut.valid_mask.value = valid_mask
        for i in range(4):
            dut.strings[i].value = strings[i]
        await Timer(1, units='ns')
        
        # Convert output to ASCII string
        result_bytes = bytes.fromhex(f"{int(dut.concatenated.value):032x}")
        result_str = ''.join(chr(b) if b != 0 else '' for b in result_bytes)
        
        expected_bytes = expected.encode('ascii').ljust(16, b'\0')
        expected_hex = expected_bytes.hex()
        
        if dut.concatenated.value == int.from_bytes(expected_bytes, 'big'):
            passed += 1
            dut._log.info(f"PASS: Mask {bin(valid_mask)} -> '{result_str}'")
        else:
            dut._log.error(f"FAIL: Mask {bin(valid_mask)}
  Got:      '{result_str}' ({dut.concatenated.value})
  Expected: '{expected}' ({expected_hex})")

    dut._log.info(f"Result: {passed}/{len(test_cases)} tests passed")