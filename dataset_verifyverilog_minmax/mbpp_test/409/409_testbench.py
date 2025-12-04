import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_min_product(dut):
    test_cases = [
        {"tuples": [(2,7), (2,6), (1,8), (4,9)], "expected": 8},
        {"tuples": [(10,20), (15,2), (5,10), (255,255)], "expected": 30},
        {"tuples": [(11,44), (10,15), (20,5), (12,9)], "expected": 100}
    ]

    passed = 0
    for test in test_cases:
        packed_val = 0
        for i, (x,y) in enumerate(test["tuples"]):
            packed_val |= ((x & 0xFF) << 8 | (y & 0xFF)) << (16*i)
        dut.tuples.value = packed_val
        await Timer(1, units='ns')
        if dut.min_product.value.integer == test["expected"]:
            passed += 1
            dut._log.info(f"PASS: {test['tuples']} => {test['expected']}")
        else:
            dut._log.error(f"FAIL: {test['tuples']} => {dut.min_product.value}, expected {test['expected']}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")