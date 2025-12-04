import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue


def expected_binary(decimal_val):
    return BinaryValue(bin(decimal_val)[2:].zfill(16), n_bits=16)


def expected_bits(decimal_val):
    if decimal_val == 0:
        return 1
    return len(bin(decimal_val)[2:])


@cocotb.test()
async def test_converter(dut):
    test_cases = [
        (8, '1000', 4),
        (18, '10010', 5),
        (7, '111', 3),
        (255, '11111111', 8),
        (0, '0', 1),
        (65535, '1111111111111111', 16)
    ]

    passed = 0
    for decimal_val, _, expected_bits in test_cases:
        dut.decimal_in.value = decimal_val
        await Timer(1, units='ns')
        
        expected_bin = expected_binary(decimal_val)
        actual_bin = dut.binary_out.value
        actual_bits = dut.significant_bits.value

        if actual_bin == expected_bin and actual_bits == expected_bits:
            passed += 1
            dut._log.info(f"PASS: {decimal_val} -> {actual_bin.binstr} ({actual_bits} bits)")
        else:
            dut._log.error(f"FAIL: {decimal_val}
"
                          f"  Expected: {expected_bin.binstr} ({expected_bits} bits)
"
                          f"  Received: {actual_bin.binstr} ({actual_bits} bits)")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)