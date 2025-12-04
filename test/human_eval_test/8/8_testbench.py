import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_sum_product(dut):
    test_cases = [
        # (len, numbers, expected_sum, expected_product)
        (0, 0x0000000000000000, 0, 1),
        (3, 0x0101010000000000, 3, 1),
        (2, 0x6400000000000000, 100, 0),
        (3, 0x0305070000000000, 15, 105),
        (1, 0x0A00000000000000, 10, 10),
        (4, 0x0102030400000000, 10, 24)
    ]
    passed = 0
    for len_val, nums, exp_sum, exp_prod in test_cases:
        dut.len.value = len_val
        dut.numbers.value = nums
        await Timer(1, units='ns')
        if int(dut.sum.value) == exp_sum and int(dut.product.value) == exp_prod:
            passed += 1
            dut._log.info(f"PASS: len={len_val} nums={hex(nums)} res=({exp_sum}, {exp_prod})")
        else:
            dut._log.error(f"FAIL: len={len_val} nums={hex(nums)} got=({int(dut.sum.value)}, {int(dut.product.value)}), expected=({exp_sum}, {exp_prod})")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")