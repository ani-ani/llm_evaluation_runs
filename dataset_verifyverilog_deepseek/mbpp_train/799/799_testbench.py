import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_rotation(dut):
    test_cases = [
        (16, 2, 64),
        (10, 2, 40),
        (99, 3, 792),
        (1, 3, 8),
        (0b0101, 3, 0b101000),
        (0b11101, 3, 0b11101000)
    ]

    passed = 0
    for n_val, d_val, expected in test_cases:
        dut.n.value = n_val
        dut.d.value = d_val
        await Timer(1, units='ns')
        result = dut.result.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val}, d={d_val} => {result}")
        else:
            dut._log.error(f"FAIL: n={n_val}, d={d_val} => {result}, expected {expected}")
    dut._log.info(f"Test summary: {passed}/{len(test_cases)} passed")