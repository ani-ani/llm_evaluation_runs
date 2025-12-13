import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_min_cost(dut):
    test_cases = [
        (1, 0),
        (2, 0),
        (3, 1),
        (4, 1),
        (10, 4),
        (65535, 32767)  # Max 16-bit test case
    ]
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        if int(dut.min_cost.value) == expected:
            passed += 1
        else:
            dut._log.error("Test failed: n=%d => %d, expected %d" % 
                          (n_val, int(dut.min_cost.value), expected))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))
    assert passed == len(test_cases), "Some tests failed"