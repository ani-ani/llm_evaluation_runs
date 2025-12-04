import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_quotient(dut):
    test_cases = [
        (10, 3, 3),
        (4, 2, 2),
        (20, 5, 4),
        (10, 1, 10), 
        (5, 10, 0),
        (255, 1, 255)
    ]
    passed = 0
    for a, b, expected in test_cases:
        dut.a.value = a
        dut.b.value = b
        await Timer(1, units='ns')
        actual = dut.q.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {a}//{b} = {actual}")
        else:
            dut._log.error(f"FAIL: {a}//{b} = {actual}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")