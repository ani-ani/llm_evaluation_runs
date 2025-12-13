import cocotb
from cocotb.triggers import Timer
import numpy as np

@cocotb.test()
async def test_unit_multiplier(dut):
    test_cases = [
        (148, 412, 16),    # 8*2 = 16
        (19, 28, 72),      # 9*8 = 72
        (2020, 1851, 0),   # 0*1 = 0
        (14, -15, 20),     # 4*5 = 20
        (76, 67, 42),      # 6*7 = 42
        (17, 27, 49),      # 7*7 = 49
        (0, 1, 0),         # 0*1 = 0
        (0, 0, 0)          # 0*0 = 0
    ]

    passed = 0
    for a, b, expected in test_cases:
        dut.a.value = a
        dut.b.value = b
        await Timer(1, units='ns')
        result = dut.product.value.integer
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {a},{b} -> {result}")
        else:
            dut._log.error(f"FAIL: {a},{b} -> {result}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed}/{total} tests"