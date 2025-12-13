import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_last_digit(dut):
    test_cases = [
        (0, 1),
        (1, 1),
        (2, 2),
        (3, 6),
        (4, 4),
        (5, 0),
        (21, 0),
        (30, 0)
    ]
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.last_digit.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} → {result}")
        else:
            dut._log.error(f"FAIL: n={n_val} got {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")