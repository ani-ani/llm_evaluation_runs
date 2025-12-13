import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_check_power_sum(dut):
    test_cases = [
        (10, 1),
        (7, 0),
        (14, 1),
        (0, 1),
        (255, 0),
        (128, 1)
    ]
    passed = 0
    for n, expected in test_cases:
        dut.n.value = n
        await Timer(1, units='ns')
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: n={n} ={dut.result.value}, expected {expected}")
        else:
            dut._log.error(f"FAIL: n={n} ={dut.result.value}, expected {expected}")
    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")