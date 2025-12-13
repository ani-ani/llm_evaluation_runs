import cocotb
from cocotb.triggers import Timer

# Precomputed test data (example values - real implementation would use full table)
TEST_DATA = [0]*65536
TEST_DATA[1] = 1
TEST_DATA[2] = 2
TEST_DATA[3] = 1
TEST_DATA[4] = 2
TEST_DATA[5] = 1
TEST_DATA[8] = 2

@cocotb.test()
async def test_counter(dut):
    test_cases = [
        (1, 10, 18),  # Scaled sample 1
        (5, 8, 8),    # Scaled sample 1
        (17, 144, 265)# Adjusted sample 2
    ]
    passed = 0
    for A, B, expected in test_cases:
        dut.A.value = A
        dut.B.value = B
        await Timer(1, units='ns')
        result = dut.count.value
        if result == expected:
            passed += 1
        else:
            dut._log.error("Test failed: [%d,%d] = %%d (expected %%d)" % (A, B, result, expected))
    dut._log.info("%%d/%%d tests passed" % (passed, len(test_cases)))