import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_multiplier(dut):
    test_cases = [
        (10, 20, 200),
        (5, 10, 50),
        (4, 8, 32),
        (-5, 10, -50),
        (127, 127, 16129),
        (0, 100, 0)
    ]
    passed = 0
    for x, y, expected in test_cases:
        dut.x.value = x
        dut.y.value = y
        await Timer(1, units='ns')
        actual = dut.result.value.signed_integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {x}*{y}={actual}")
        else:
            dut._log.error(f"FAIL: {x}*{y}={actual}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")