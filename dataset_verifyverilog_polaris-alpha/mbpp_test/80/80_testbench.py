import cocotb
from cocotb.triggers import Timer
@cocotb.test()
async def test_tetrahedral(dut):
    test_cases = [
        (5, 35),
        (6, 56),
        (7, 84),
        (0, 0),   # Edge case: minimum input
        (21, 1771)  # Max for 8-bit calculation that fits in 16-bit output
    ]
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        actual = dut.result.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} => {actual} (expected {expected})")
        else:
            dut._log.error(f"FAIL: n={n_val} => {actual}, expected {expected}")
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")