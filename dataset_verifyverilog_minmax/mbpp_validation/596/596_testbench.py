import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_tuple_size(dut):
    test_cases = [
        (b'ABCD', 4),  # ASCII chars (1 byte each)
        (32'h01010101, 4),  # Numeric values
        (32'hA1B2A1B2, 4)   # Mixed hex values
    ]
    passed = 0
    for data, expected in test_cases:
        dut.tuple_data.value = data
        await Timer(1, units='ns')
        if dut.byte_size.value == expected:
            passed += 1
            dut._log.info(f"PASS: Input {hex(data)} -> {int(dut.byte_size.value)} bytes")
        else:
            dut._log.error(f"FAIL: Input {hex(data)} -> {int(dut.byte_size.value)} bytes, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"