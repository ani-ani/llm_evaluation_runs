import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_triangular(dut):
    test_cases = [
        (1, 2),
        (2, 4),
        (3, 14),
        (4, 45),
        (5, 142),
        (6, 447)
    ]
    passed = 0
    
    for (digits, expected) in test_cases:
        dut.n_digits.value = digits
        await Timer(1, units='ns')
        result = dut.index.value
        
        if int(result) == expected:
            passed += 1
            dut._log.info(f"PASS: {digits} digits → index={result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: {digits} digits → got {result}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
    assert passed == total, "Some tests failed"