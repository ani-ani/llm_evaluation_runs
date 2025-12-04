import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_swap(dut):
    test_cases = [
        (10, 20, (20, 10)),
        (15, 17, (17, 15)),
        (100, 200, (200, 100))
    ]
    passed = 0
    for a, b, expected in test_cases:
        dut.a.value = a
        dut.b.value = b
        await Timer(1, units='ns')
        actual = (dut.out0.value.integer, dut.out1.value.integer)
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: ({a},{b}) => {actual}")
        else:
            dut._log.error(f"FAIL: ({a},{b}) => {actual}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")