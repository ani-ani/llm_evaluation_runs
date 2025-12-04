import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_diff_check(dut):
    test_cases = [
        (5, 1),   # 5%4=1 -> True
        (10, 0),  # 10%4=2 -> False
        (15, 1),  # 15%4=3 -> True
        (2, 0),   # edge case: 2%4=2 -> False
        (0, 1),   # edge case: 0%4=0 -> True
        (255, 1)  # max value: 255%4=3 -> True
    ]
    
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        actual = dut.result.value
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} => result={actual}")
        else:
            dut._log.error(f"FAIL: n={n_val} => {actual}, expected {expected}")
    
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), f"{len(test_cases)-passed} tests failed"