import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_triangle(dut):
    test_cases = [
        # Original valid cases
        (3, 4, 5, True),
        (10, 6, 8, True),
        (7, 24, 25, True),
        (5, 12, 13, True),
        (15, 8, 17, True),
        (48, 55, 73, True),
        
        # Original invalid cases
        (1, 2, 3, False),
        (2, 2, 2, False),
        (10, 5, 7, False),
        (1, 1, 1, False),
        (2, 2, 10, False),
        
        # Edge cases
        (0, 0, 0, False),  # Zero length
        (4, 3, 5, True)    # Permutation check
    ]
    
    passed = 0
    for a, b, c, expected in test_cases:
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        await Timer(1, units='ns')
        result = dut.is_right.value
        if bool(result) == expected:
            passed += 1
            dut._log.info(f"PASS: {a},{b},{c} => {expected}")
        else:
            dut._log.error(f"FAIL: {a},{b},{c} => {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")