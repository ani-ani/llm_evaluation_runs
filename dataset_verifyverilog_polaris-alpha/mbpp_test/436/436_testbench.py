import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_neg_nos(dut):
    test_cases = [
        ([-1, 4, 5, -6], [-1, -6]),
        ([-1, -2, 3, 4], [-1, -2]),
        ([-7, -6, 8, 9], [-7, -6])
    ]
    passed = 0
    for inputs, expected in test_cases:
        dut.num0.value = inputs[0]
        dut.num1.value = inputs[1]
        dut.num2.value = inputs[2]
        dut.num3.value = inputs[3]
        await Timer(1, units='ns')
        
        outputs = []
        if dut.out0.value.signed_integer != 0:
            outputs.append(dut.out0.value.signed_integer)
        if dut.out1.value.signed_integer != 0:
            outputs.append(dut.out1.value.signed_integer)
        if dut.out2.value.signed_integer != 0:
            outputs.append(dut.out2.value.signed_integer)
        if dut.out3.value.signed_integer != 0:
            outputs.append(dut.out3.value.signed_integer)
        
        if outputs == expected:
            passed += 1
            dut._log.info(f"PASS: Input {inputs} → Output {outputs}")
        else:
            dut._log.error(f"FAIL: Input {inputs} → Output {outputs}, Expected {expected}")
            
    dut._log.info(f"RESULT: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)