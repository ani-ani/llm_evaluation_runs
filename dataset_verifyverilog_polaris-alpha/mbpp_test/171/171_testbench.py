import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_perimeter(dut):
    test_cases = [
        (5, 25),
        (10, 50),
        (15, 75),
        (255, 1275),  # max 8-bit input
        (0, 0)  # zero edge case
    ]
    passed = 0
    for a_val, expected in test_cases:
        dut.a.value = a_val
        await Timer(1, units='ns')
        actual = dut.perimeter.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {a_val} -> {actual}")
        else:
            dut._log.error(f"FAIL: {a_val} -> {actual}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)