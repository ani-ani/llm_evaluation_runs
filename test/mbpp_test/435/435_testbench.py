import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_last_digit(dut):
    test_cases = [
        (123, 3),
        (25, 5),
        (30, 0),
        (255, 5),   # max 8-bit value
        (0, 0),     # zero case
        (159, 9)    # additional test
    ]
    passed = 0
    for num, expected in test_cases:
        dut.n.value = num
        await Timer(1, units='ns')
        result = dut.digit.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {num} → {result}")
        else:
            dut._log.error(f"FAIL: {num} → {result}, expected {expected}")
    dut._log.info(f"
SUMMARY: {passed}/{len(test_cases)} tests passed")