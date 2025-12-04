import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_centered_hexagonal(dut):
    test_cases = [
        (10, 271),
        (2, 7),
        (9, 217),
        (1, 1),
        (0, 1),
        (15, 631)
    ]
    
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.hex_num.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} => {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: n={n_val} => {result}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed.")
    assert passed == total, f"Failed {total-passed}/{total} tests"