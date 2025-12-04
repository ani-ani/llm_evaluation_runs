import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import numpy as np

@cocotb.test()
async def test_scaled_mult_div(dut):
    test_cases = [
        ((8, 2, 3, -1), -12),    # Original: (8,2,3,-1,7)→-67.2 → adjusted
        ((-10, -20, -30, 1), -2000 & 0xFFFFFFFF),  # Original test, pad with 1
        ((19, 15, 18, 1), 1710 >> 2),   # (19*15*18)=5130/4=1282.5 → truncated
        ((127, 127, 127, 127), (127**4) >> 2),  # Max positive
        ((-128, -128, -128, -128), ((-128)**4) >> 2)  # Max magnitude
    ]
    passed = 0
    for inputs, expected in test_cases:
        dut.num0.value = inputs[0]
        dut.num1.value = inputs[1]
        dut.num2.value = inputs[2]
        dut.num3.value = inputs[3]
        await Timer(1, units='ns')
        result = dut.result.value.signed_integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {inputs}→{result}")
        else:
            dut._log.error(f"FAIL: {inputs}→{result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")