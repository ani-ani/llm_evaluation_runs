import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue

@cocotb.test()
async def test_upper_counter(dut):
    test_cases = [
        # Original: 'PYthon' -> 'PYthon\\0\\0' (pad with nulls)
        (b'PYthon\\x00\\x00', 2),  # P,Y
        (b'BigData\\x00', 2),       # B,D
        (b'program\\x00\\x00', 0),
        # Additional edge cases
        (b'ABCDEFGH', 8),           # All uppercase
        (b'abcdefgh', 0),           # All lowercase
        (b'A1B2C3D4', 4)            # Mixed case
    ]

    passed = 0
    for input_bytes, expected in test_cases:
        # Convert bytes to 64-bit integer
        byte_val = int.from_bytes(input_bytes, byteorder='big')
        dut.str_bytes.value = byte_val
        await Timer(1, units='ns')
        result = dut.count.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {input_bytes} -> {result}")
        else:
            dut._log.error(f"FAIL: {input_bytes} -> {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")