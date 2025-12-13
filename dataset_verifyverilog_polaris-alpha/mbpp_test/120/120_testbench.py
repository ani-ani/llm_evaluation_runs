import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_max_abs_product(dut):
    test_cases = [
        # (inputs, expected)
        ((2,7, 2,6, 1,8, 4,9), 36),
        ((10,20,15,2,5,10,0,0), 200),
        ((11,44,10,15,20,5,12,9), 484),
        # Edge cases
        ((-128,-128,127,127,-1,-1,1,1), 16384),
        ((0,100,5,0,-3,25,10,10), 2500)
    ]
    passed = 0
    for case in test_cases:
        inputs, expected = case
        dut.a0.value = inputs[0]
        dut.b0.value = inputs[1]
        dut.a1.value = inputs[2]
        dut.b1.value = inputs[3]
        dut.a2.value = inputs[4]
        dut.b2.value = inputs[5]
        dut.a3.value = inputs[6]
        dut.b3.value = inputs[7]
        await Timer(1, units='ns')
        result = dut.max_product.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: Inputs {inputs} -> {result}")
        else:
            dut._log.error(f"FAIL: Inputs {inputs} -> {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")