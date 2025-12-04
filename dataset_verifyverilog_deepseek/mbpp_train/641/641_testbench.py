import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_nonagonal(dut):
    test_cases = [
        (10, 325),
        (15, 750),
        (18, 1089)
    ]
    passed = 0
    
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.result.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} => {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: n={n_val} => {result}, expected {expected}")
    
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")