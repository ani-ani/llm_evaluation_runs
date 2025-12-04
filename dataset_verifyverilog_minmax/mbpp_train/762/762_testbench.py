import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_month(dut):
    test_cases = [
        (4, 1),
        (6, 1),
        (9, 1),
        (11, 1),
        (1, 0),
        (2, 0),
        (3, 0),
        (7, 0),
        (8, 0),
        (12, 0)
    ]
    passed = 0
    for month_num, expected in test_cases:
        dut.month_num.value = month_num
        await Timer(1, units='ns')
        result = dut.is_30days.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: Month {month_num} => {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: Month {month_num} => {result}, expected {expected}")
    dut._log.info(f"RESULT: {passed}/{len(test_cases)} tests passed")