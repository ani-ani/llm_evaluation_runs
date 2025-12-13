import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_rectangle_area(dut):
    test_cases = [
        (10, 20, 200),
        (10, 5, 50),
        (4, 2, 8),
        (255, 255, 65025),
        (0, 15, 0),
        (15, 15, 225)
    ]
    passed = 0
    for l, b, expected in test_cases:
        dut.l.value = l
        dut.b.value = b
        await Timer(1, units='ns')
        actual = dut.area.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {l}*{b}={actual}")
        else:
            dut._log.error(f"FAIL: {l}*{b}={actual}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")