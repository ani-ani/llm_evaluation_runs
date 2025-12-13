import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_tuple_compare(dut):
    test_cases = [
        # Original test cases expanded to 4 elements (last element padded with 0)
        ((1, 2, 3, 0), (2, 3, 4, 0), False),   # Original Test 1
        ((4, 5, 6, 0), (3, 4, 5, 0), True),    # Original Test 2
        ((11, 12, 13, 0), (10, 11, 12, 0), True),  # Original Test 3
        # Additional edge cases
        ((255, 255, 255, 255), (254, 254, 254, 254), True),  # Max values
        ((1, 1, 1, 1), (1, 1, 1, 1), False)  # Equal values
    ]

    passed = 0
    for i, (t1, t2, expected) in enumerate(test_cases):
        for idx in range(4):
            dut.t1[idx].value = t1[idx]
            dut.t2[idx].value = t2[idx]
        await Timer(1, units='ns')
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"TEST {i+1}: PASS - {t1} vs {t2} => {dut.result.value}")
        else:
            dut._log.error(f"TEST {i+1}: FAIL - {t1} vs {t2} => {dut.result.value}, expected {expected}")
    
    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")