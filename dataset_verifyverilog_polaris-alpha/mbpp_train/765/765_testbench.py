import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_polite(dut):
    test_cases = [
        (7, 11),   # Original test case 1
        (4, 7),    # Original test case 2
        (9, 13),   # Original test case 3
        (0, 1),    # Edge case: minimum input
        (1, 3),    # Polite number #1
        (255, 264) # Max 8-bit input
    ]
    
    passed = 0
    for n_in, expected in test_cases:
        dut.n.value = n_in
        await Timer(1, units='ns')
        result = int(dut.result.value)
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {n_in} -> {result}")
        else:
            dut._log.error(f"FAIL: {n_in} -> {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")