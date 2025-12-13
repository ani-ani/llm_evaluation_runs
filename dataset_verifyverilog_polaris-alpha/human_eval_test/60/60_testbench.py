import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_sum_to_n(dut):
    test_cases = [
        (1, 1),
        (6, 21),
        (11, 66),
        (30, 465),
        (100, 5050)
    ]
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.sum.value
        if int(result) == expected:
            passed += 1
            dut._log.info(f"PASS: sum_to_n({n_val}) = {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: sum_to_n({n_val}) = {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")