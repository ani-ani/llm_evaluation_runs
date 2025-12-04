import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue

@cocotb.test()
async def test_set_even_bits(dut):
    test_cases = [
        (10, 10),   # 00001010 -> 00001010 (no change)
        (20, 30),   # 00010100 -> 00011110
        (30, 30),   # 00011110 -> 00011110 (no change)
        (0, 85)     # 00000000 -> 01010101
    ]
    passed = 0
    for (input_val, expected) in test_cases:
        dut.num.value = input_val
        await Timer(1, units='ns')
        actual = dut.result.value.integer
        if actual == expected:
            passed += 1
            dtype = 'HEX' if input_val == 0 else 'DEC'
            dut._log.info(f"PASS: 0x{input_val:02x} ({input_val}) → 0x{actual:02x} ({actual})")
        else:
            dut._log.error(f"FAIL: 0x{input_val:02x} → 0x{actual:02x} ({actual}), expected 0x{expected:02x} ({expected})")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")