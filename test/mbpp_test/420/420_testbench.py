import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_cube_sum(dut):
    test_cases = [
        (2, 72),
        (3, 288),
        (4, 800),
        (1, 8),  # Edge case: n=1
        (5, 1800) # Additional test case
    ]
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.sum.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} =\> {result}")
        else:
            dut._log.error(f"FAIL: n={n_val} got {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")