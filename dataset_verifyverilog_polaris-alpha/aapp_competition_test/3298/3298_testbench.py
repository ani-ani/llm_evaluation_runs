import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_perm_counter(dut):
    test_cases = [
        (4, 14),   # Original sample adapted to unique case
        (5, 90),   # Original duplicate case simplified to unique count
        (3, 2),    # Additional test case
        (8, 47622) # Max supported size
    ]
    passed = 0
    for (n_val, expected) in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result_val = dut.count.value
        if result_val == expected:
            passed += 1
        else:
            dut._log.error("Test failed: For n=%d, expected=%d, got=%d" % (n_val, expected, result_val))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))
    assert passed == len(test_cases)