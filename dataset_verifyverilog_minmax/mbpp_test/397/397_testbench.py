import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_median(dut):
    test_cases = [
        (25, 55, 65, 55),
        (20, 10, 30, 20),
        (15, 45, 75, 45),
        (0, 0, 0, 0),     # Edge: all zeros
        (255, 255, 1, 255), # Edge: max values
        (50, 100, 75, 75) # Additional test
    ]
    passed = 0
    for a, b, c, expected in test_cases:
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        await Timer(1, units='ns')
        result = dut.median.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {a}, {b}, {c} => {expected}")
        else:
            dut._log.error(f"FAIL: {a}, {b}, {c} => {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")