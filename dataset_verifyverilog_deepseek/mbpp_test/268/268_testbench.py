import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_star(dut):
    test_cases = [
        (0, 1),   # Edge case: 6*0*(-1)+1=1
        (1, 1),   # Test base case: 6*1*0+1=1
        (2, 13),  # 6*2*1+1=13
        (3, 37),  # Original test case
        (4, 73),  # Original test case
        (5, 121), # Original test case
        (6, 181), # 6*6*5+1=181
        (16, 1441) # Max value test
    ]
    passed = 0
    for n, expected in test_cases:
        dut.n.value = n
        await Timer(1, units='ns')
        if int(dut.star_num.value) == expected:
            passed += 1
            dut._log.info(f"PASS: star({n})={expected}")
        else:
            dut._log.error(f"FAIL: n={n} got {dut.star_num.value} expected {expected}")
    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")