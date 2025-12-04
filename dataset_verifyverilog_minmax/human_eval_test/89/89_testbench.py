import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_string_encrypt(dut):
    test_cases = [
        ("hi", 2, "lm"),
        ("asdfghjkl", 9, "ewhjklnop"),
        ("gf", 2, "kj"),
        ("et", 2, "ix"),
        ("faewfawefaewg", 13, "jeiajeaijeiak"),
        ("hellomyfriend", 13, "lippsqcjvmirh"),
        ("a", 1, "e")
    ]
    passed = 0

    def str_to_bits(s):
        padded = s.encode() + b"\\x00" * (16 - len(s))
        return int.from_bytes(padded, byteorder="big", signed=False)

    def mask_result(bits, length):
        keep_mask = (1 << (16*8)) - (1 << ((16-length)*8))
        return bits & keep_mask

    for s, length, expected in test_cases:
        input_bits = str_to_bits(s)
        expected_bits = str_to_bits(expected)
        expected_masked = mask_result(expected_bits, length)

        dut.data_in.value = input_bits
        dut.length.value = length
        await Timer(1, units= "ns")

        output_bits = dut.data_out.value.integer
        output_masked = mask_result(output_bits, length)

        if output_masked == expected_masked:
            passed += 1
            dut._log.info(f"PASS: {s} -> '{expected}'")
        else:
            received = output_bits.to_bytes(16, 'big')[:length].decode(errors='ignore')
            dut._log.error(f"FAIL: '{s}' ({length}) got '{received}', expects '{expected}'")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")