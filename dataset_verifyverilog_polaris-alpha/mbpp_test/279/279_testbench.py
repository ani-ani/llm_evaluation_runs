import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_decagonal(dut):
    test_cases = [
        (0, 0),    # 4*0 - 3*0 = 0
        (1, 1),    # 4*1 - 3*1 = 1
        (3, 27),   # Original test case 1
        (7, 175),  # Original test case 2
        (10, 370), # Original test case 3
        (255, 257535) # Max value test (4*255² - 3*255)
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