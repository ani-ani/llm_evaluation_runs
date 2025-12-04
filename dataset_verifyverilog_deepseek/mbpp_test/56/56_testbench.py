import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_rev_checker(dut):
    test_cases = [
        (70, 0),
        (23, 0),
        (73, 1),
        (1, 1),   # 2*1 = 2, 1+1=2 → True
        (0, 0),   # 0+1=1 ≠ 0
        (255, 0), # rev=552, 2*552=1104 ≠ 256
        (37, 1)   # rev=73 → 2*73=146 == 37+1=38? 0
    ]
    passed = 0
    
    for num, expected in test_cases:
        dut.num.value = num
        await Timer(1, units='ns')
        actual = dut.check.value
        
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: num={num} => {actual} (expected {expected})")
        else:
            dut._log.error(f"FAIL: num={num} => {actual}, expected {expected}")
    
    dut._log.info(f"RESULTS: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"