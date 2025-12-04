import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_polygon_counter(dut):
    test_cases = [
        # (R,C,expected) with R/C mapped to 0-based encoding
        (1,2,3),
        (2,1,3),
        (2,2,13)
    ]
    passed = 0
    for (true_R, true_C, expected) in test_cases:
        dut.R.value = true_R - 1  # Convert to 0-based
        dut.C.value = true_C - 1
        await Timer(1, units='ns')
        actual = dut.count.value.integer
        if actual == expected:
            passed += 1
        else:
            dut._log.error("FAIL: R=%d,C=%d → %d (expected %d)" % (true_R, true_C, actual, expected))
    dut._log.info("PASSED: %d/%d tests" % (passed, len(test_cases)))