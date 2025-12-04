import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_none_check(dut):
    test_cases = [
        ((10,4,5,6,0xFF), True),
        ((7,8,9,11,14), False),
        ((1,2,3,4,0xFF), True),
        ((0,0,0,0,0), False),
        ((0xFF,0xFF,0xFF,0xFF,0xFF), True)
    ]

    passed = 0
    for idx, (inputs, expected) in enumerate(test_cases):
        for i in range(5):
            dut.tuple_in[i].value = inputs[i]
        await Timer(1, units='ns')
        if dut.res.value == expected:
            passed += 1
            dut._log.info(f"PASS {idx+1}: {inputs} -> {expected}")
        else:
            dut._log.error(f"FAIL {idx+1}: {inputs} -> {dut.res.value}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")