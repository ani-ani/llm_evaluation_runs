import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_binary_seq(dut):
    test_cases = [
        (1, 2),
        (2, 6),
        (3, 20),
        (4, 70)  # Calculated for n=4 using the formula
    ]
    passed = 0
    
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.count.value.integer
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} → {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: n={n_val} → {result}, expected {expected}")
    
    dut.tests_total = len(test_cases)
    dut.tests_passed = passed
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)