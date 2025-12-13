import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_divisor_count(dut):
    test_cases = [
        (10, True),
        (100, False),
        (125, True)
    ]
    
    passed = 0
    for n, expected in test_cases:
        dut.n.value = n
        await Timer(1, units='ns')
        result = bool(dut.is_even.value)
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n} => {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: n={n} => {result}, expected {expected}")
    
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")