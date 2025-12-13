import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_sum_checker(dut):
    test_cases = [
        (4, False),
        (6, False),
        (8, True),
        (10, True),
        (11, False),
        (12, True),
        (13, False),
        (16, True)
    ]
    passed = 0

    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.result.value
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} => {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: n={n_val} => {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    if passed < len(test_cases):
        raise TestFailure("Some tests failed")