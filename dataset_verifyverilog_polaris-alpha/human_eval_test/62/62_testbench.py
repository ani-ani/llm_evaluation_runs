import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_derivative(dut):
    test_cases = [
        # Input coeffs (padded to 8)      Expected output (padded to 7)
        ([3,1,2,4,5,0,0,0],            [1,4,12,20,0,0,0]),
        ([1,2,3,0,0,0,0,0],            [2,6,0,0,0,0,0]),
        ([3,2,1,0,4,0,0,0],            [2,2,0,16,0,0,0]),
        ([1,0,0,0,0,0,0,0],            [0,0,0,0,0,0,0]),  # Original [1]
        ([0,0,0,0,0,0,0,0],            [0,0,0,0,0,0,0]),
        ([4,7,0,9,10,2,5,0],           [7,0,27,40,10,30,0]) 
    ]
    passed = 0
    for coeffs, expected in test_cases:
        for i in range(8):
            dut.coeffs[i].value = coeffs[i]
        await Timer(1, units='ns')
        results = [dut.deriv[i].value.integer for i in range(7)]
        if results == expected:
            passed += 1
            dut._log.info(f"PASS: {coeffs[:5]}... → {expected[:5]}...")
        else:
            dut._log.error(f"FAIL: Input {coeffs}
  Got {results}
  Expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")